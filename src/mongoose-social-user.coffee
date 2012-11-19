mongoose = require('mongoose')
SocialReq = require('social-request')
async = require('async')

module.exports = (schema, options) ->
  socialReq = new SocialReq()
  socialReq
    .use('google', {clientId: options.google.clientId, clientSecret: options.google.clientSecret})
    .use('googleplus', {clientId: options.google.clientId, clientSecret: options.google.clientSecret})
    .use('facebook', {appId: options.facebook.appId, appSecret: options.facebook.appSecret})
  schema.add
    auth:
      facebook:
        id: String
        username: String
        aT: String
        createdAt: Date
        userData: {}
        contacts: Array
      twitter:
        id: String
        username: String
        aT: String
        aTS: String
        createdAt: Date
        userData: {}
        contacts: Array
      google:
        id: String
        username: String
        aT: String
        aTS: String
        createdAt: Date
        userData: {}
        contacts: Array
  _findOrCreateUser = (params, done) ->
    return done(new Error("couldn't log you in"))  if not params.service or not params.session or not params.data
    self = @
    upsertSocialIdToDatabase = (user, newUser, done) ->
      user.auth[params.service].id = params.data.id
      user.auth[params.service].username = params.data.username
      user.auth[params.service].createdAt = new Date() if newUser
      user.auth[params.service].aT = params.data.aT
      user.auth[params.service].aTS = params.data.aTS
      if not user.auth[params.service].userData?
        user.auth[params.service].userData = params.data
      else 
        for param of params.data
          user.auth[params.service].userData[param] = params.data[param]
        user.markModified('auth.' + params.service + '.userData')
      user.save (err) ->
        done err, user, newUser
    userParams = {}
    userParams['auth.' + params.service + '.id'] = params.data.id
    if params.session?.auth?.userId?
      @findById params.session.auth.userId, (err, user) ->
        return done(err, null) if err
        return done(null) if not user?
        self.findOne userParams, (err, occupyingUser) ->
          return done(err ? new Error('Another user has already linked this account'))  if err? or (occupyingUser and occupyingUser.id isnt params.session.auth.userId)
          upsertSocialIdToDatabase user, false, done
    else
      @findOne userParams, (err, user) ->
        return done(err, null)  if err
        return upsertSocialIdToDatabase user, false, done if user?
        self.create {}, (err, user) ->
          upsertSocialIdToDatabase user, true, done
  schema.statics.findOrCreateUser = (service) ->
    self = @
    switch service
      when 'googlehybrid' then return (session, userAttributes) ->
        promise = @Promise()
        params =
          service: "google"
          session: session
          data: userAttributes
        params.data.id = params.data.claimedIdentifier.split('=')[1]
        params.data.username = params.data.email
        params.data.userData = {
          email: params.data.email,
          firstname: params.data.firstname,
          lastname: params.data.lastname
        }
        params.data.aT = params.data.access_token
        params.data.aTS = params.data.access_token_secret
        _findOrCreateUser.bind(self) params, (err, user, newUser) ->
          return promise.fulfill [err] if err
          session.newUser = newUser
          session.authUserData = params.data
          session.authUserData.service = params.service
          promise.fulfill user
        promise
      when 'google' then return (session, accessToken, accessTokExtra, userAttributes) ->
        promise = @Promise()
        params =
          service: "google"
          session: session
          data: userAttributes
        params.data.username = params.data.email
        params.data.aT = accessToken
        params.data.aTE = accessTokExtra
        _findOrCreateUser.bind(self) params, (err, user, newUser) ->
          return promise.fulfill [err] if err
          session.newUser = newUser
          session.authUserData = params.data
          session.authUserData.service = params.service
          promise.fulfill user
        promise
      when 'facebook' then return (session, accessToken, accessTokExtra, fbUserMetaData) ->
        promise = @Promise()
        params =
          service: "facebook"
          session: session
          data: fbUserMetaData
        params.data.aT = accessToken
        params.data.aTE = accessTokExtra
        _findOrCreateUser.bind(self) params, (err, user, newUser) ->
          return promise.fulfill [err] if err
          session.newUser = newUser
          session.authUserData = params.data
          session.authUserData.service = params.service
          promise.fulfill user
        promise
  schema.methods.getSocial = (params, done) ->
    self = @
    socialReq.getTokens (id, cb) ->
      cb
        facebook:
          access_token: self.auth.facebook.aT
        google: 
          access_token: self.auth.google.aT
          access_token_secret: self.auth.google.aTS
    socialReq.get @.id, params, (err, results) ->
      processingFunctions = []
      for requestType of results
        switch requestType
          when 'google'
            if results[service].contacts?
              processingFunctions.push (cb) ->
                async.filter results[service].contacts, (contact, cb) ->
                  cb contact.email?
                , (contacts) ->
                  async.sortBy contacts, (contact, cb) ->
                    console.log contact.entry.gd$name?.gd$familyName
                    cb null, contact.entry.gd$name?.gd$familyName
                  , (err, contacts) ->
                    results[service].contacts = contacts
                    cb()
      async.parallel processingFunctions, (err, processingResults) ->
        done err, results

  ###
  schema.on 'init', (model) ->
    socialReq.getTokens (id, cb) ->
      model.findById id, (err, user) ->
        console.log err, user
        return cb(err || new Error 'User does not exist') if err? or not user?
        cb
          facebook:
            access_token: user.auth.facebook.aT
          google: 
            access_token: user.auth.google.aT
            access_token_secret: user.auth.google.aTS###

  schema.methods._invalidateAT = (service, done) ->
    return done null, @ if not @auth[service]?
    @auth[service].aT = undefined
    @auth[service].aTS = undefined
    @save done
  return