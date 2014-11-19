expect = require 'expect.js'
sinon = require 'sinon'
mongoose = require 'mongoose'
require('coffee-script')
testConfig = require '../testconfig'
async = require 'async'
SocialReq = require('social-request')

describe 'Mongoose Social Plugin', () ->
  UserSchema = {}; User = {}; SocialUserData = {}; user = {}; socialGetSpy = {};
  before (done) ->
    mongoose.connect('mongodb://localhost/mongoose-social-user-testing')
    socialReq = new SocialReq();
    socialGetSpy = sinon.spy SocialReq.prototype, 'get', (params, cb) ->
    UserSchema = new mongoose.Schema
      name: String
      email: String
    UserSchema.plugin require('../index.js'),
      google:
        clientId: testConfig.google.clientId
        clientSecret: testConfig.google.clientSecret
      facebook:
        appId: testConfig.facebook.appId
        appSecret: testConfig.facebook.appSecret
      #twitter:
        #consumerKey: testConfig.twitter.consumerKey
        #consumerSecret: testConfig.twitter.consumerSecret
      #linkedin:
        #apiKey: testConfig.linkedin.apiKey
        #secretKey: testConfig.linkedin.secretKey
      mongoose: mongoose
    User = mongoose.model('User', UserSchema)
    SocialUserData = mongoose.model('SocialUserData')
    SocialUserData.remove done

  beforeEach (done) ->
    async.parallel [
      (cb) ->
        User.remove {}, cb
    ,
      (cb) ->
        SocialUserData.remove {}, cb
    ], () ->
      async.parallel [
        (cb) ->
          User.create [
              _id: '000000000000000000000004'
            ,
              _id: '000000000000000000000003'
              email: 'google@gmail.com'
              auth:
                google:
                  id: '114277323590337190780'
                  aT: 'iamanaccesstoken'
                  rT: 'iamarefreshtoken'
            ,
              _id: '000000000000000000000005'
              email: 'facebook@facebook.com'
              auth:
                facebook:
                  id: '198437102109342'
                  username: 'fbusername'
                  aT: 'iamasweetaccesstoken'
            ,
              _id: '000000000000000000000006'
              email: 'dude@gmail.com'
          ], cb
      ,
        (cb) ->
          SocialUserData.create [
            _user: '000000000000000000000005'
            facebook:
              userData:
                first_name: 'Will'
                last_name: 'NotStone'
          ], cb
      ], done

  after (done) ->
    # socialGetSpy.restore()
    User.remove {}, () ->
      done()

  describe 'installed', () ->
    it 'should add keys to user', (done) ->
      User = mongoose.model('User', UserSchema)
      user = new User()
      user.auth.facebook.id = 'abcd'
      user.auth.google.id = 'defg'
      user.auth.twitter.id = 'ghik'
      expect(user.auth.facebook.id).to.be 'abcd'
      expect(user.auth.google.id).to.be 'defg'
      expect(user.auth.twitter.id).to.be 'ghik'
      done()

  describe '#_invalidateAccessToken', () ->
    it 'should invalidate an access token for oauth2 for a given service', (done) ->
      User.findById '000000000000000000000003', (err, user) ->
        return done err if err
        expect(user.auth.google.aT).to.be.ok()
        expect(user.auth.google.rT).to.be.ok()
        user._invalidateAccessToken 'google', (err, user) ->
          expect(user.auth.google.aT).not.to.be.ok()
          expect(user.auth.google.rT).to.be.ok()
          done()

    it 'should invalidate an access token for oauth for a given service'

  describe '#_refreshAccessToken', () ->
    describe 'for oauth2', () ->
      describe 'for google', () ->
        it 'should refresh an access token', (done) ->
          @timeout(10000);
          User.findById '000000000000000000000003', (err, user) ->
            return done err if err
            oldAccessToken = user.auth.google.aT
            oldRefreshToken = user.auth.google.rT = testConfig.google.refresh_token
            expect(user.auth.google.aT).to.be.ok()
            expect(user.auth.google.rT).to.be.ok()
            user._refreshAccessToken 'google', (err, user) ->
              return done err if err
              expect(user.auth.google.aT).to.be.ok()
              expect(user.auth.google.aT).not.to.be oldAccessToken
              expect(user.auth.google.rT).to.be.ok()
              expect(user.auth.google.rT).to.be oldRefreshToken
              done()
        it 'should fail correctly if there is no refresh token', (done) ->
          User.findById '000000000000000000000003', (err, user) ->
            return done err if err
            user.auth.google.rT = null
            user._refreshAccessToken 'google', (err, user) ->
              expect(err.message).to.be.ok()
              expect(err.code).to.be 400
              done()
        it 'should send error information if refresh token is invalid', (done) ->
          User.findById '000000000000000000000003', (err, user) ->
            return done err if err
            user.auth.google.rT = 'failfailfail'
            user._refreshAccessToken 'google', (err, user) ->
              expect(err.message).to.be.ok()
              expect(err.code).to.be 400
              done()
    it 'should refresh an access token for oauth for a given service'

  describe '#getSocial', () ->
    describe 'with correct access token', () ->
      it 'should get and cache the requested social data', (done) ->
        @timeout(10000);
        User.findById '000000000000000000000005', (err, user) ->
          return done err  if err
          user.auth.google.aT = testConfig.google.access_token
          user.auth.google.rT = null
          user.getSocial {contacts: ['google'], details: ['google', 'googleplus']}, (err, results) ->
            return done err  if err
            expect(results.contacts.google.length).to.be.greaterThan(0)
            expect(socialGetSpy.calledWith '000000000000000000000005', {contacts: ['google'], details: ['google', 'googleplus']}).to.be.ok();
            expect(results.contacts.google.error).to.not.be.ok();
            SocialUserData.findOne {_user: '000000000000000000000005'}, (err, socialUserData) ->
              return done err  if err
              expect(socialUserData.google.contacts.length).to.be.greaterThan(0)
              expect(socialUserData.google.userData.name).to.be.ok()
              expect(socialUserData.google.userData.given_name).to.be.ok()
              expect(socialUserData.googleplus.userData.name.givenName).to.be.ok()
              done();
    describe 'with incorrect access token', () ->
      userWithABadAccessToken = null
      beforeEach (done) ->
        User.findById '000000000000000000000005', (err, user) ->
          return done err  if err
          user.auth.google.aT = 'asdfasdfasdf'
          userWithABadAccessToken = user;
          done();
      it 'should try to refresh the access token with refresh token and request again', (done) ->
        @timeout(10000);
        userWithABadAccessToken.auth.google.rT = testConfig.google.refresh_token
        userWithABadAccessToken.auth.facebook.aT = testConfig.facebook.access_token
        userWithABadAccessToken.getSocial {contacts: ['google', 'facebook'], details: ['google', 'googleplus']}, (err, results) ->
          return done err  if err
          expect(results.contacts.google.length).to.be.greaterThan(0)
          expect(results.contacts.facebook.length).to.be.greaterThan(0)
          expect(socialGetSpy.calledWith '000000000000000000000005', {contacts: ['google', 'facebook'], details: ['google', 'googleplus']}).to.be.ok();
          expect(results.contacts.google.error).to.not.be.ok();
          SocialUserData.findOne {_user: '000000000000000000000005'}, (err, socialUserData) ->
            return done err  if err
            expect(socialUserData.google.contacts.length).to.be.greaterThan(0)
            expect(socialUserData.google.userData.name).to.be.ok()
            expect(socialUserData.google.userData.given_name).to.be.ok()
            expect(socialUserData.googleplus.userData.name.givenName).to.be.ok()
            expect(socialUserData.facebook.contacts.length).to.be.greaterThan(0)
            done();
      it 'should fail if service is not refreshable', (done) ->
        @timeout(10000);
        delete userWithABadAccessToken.auth.google.aT
        userWithABadAccessToken.auth.facebook.aT = 'wrongwrong'
        userWithABadAccessToken.getSocial {contacts: ['facebook']}, (err, results) ->
          return done err  if err
          expect(results.contacts.facebook.error.message).to.be.ok()
          done()
      it 'should pass errors without a refresh token', (done) ->
        @timeout(10000);
        delete userWithABadAccessToken.auth.google.rT
        userWithABadAccessToken.getSocial {contacts: ['google', 'facebook'], details: ['google']}, (err, results) ->
          return done err if err
          expect(results.contacts.facebook.error.message).to.be.ok()
          expect(results.contacts.google.error.message).to.be.ok()
          expect(results.details.google.error.message).to.be.ok()
          done();
      it 'should pass errors with a bad refresh token', (done) ->
        @timeout(10000);
        userWithABadAccessToken.auth.google.rT = 'failfailfail'
        userWithABadAccessToken.getSocial {contacts: ['google', 'facebook'], details: ['google']}, (err, results) ->
          return done err if err
          expect(results.contacts.facebook.error.message).to.be.ok()
          expect(results.contacts.google.error.message).to.be.ok()
          expect(results.details.google.error.message).to.be.ok()
          done();

  describe '.findOrCreateUser', () ->
    promiseScope =
      Promise: () ->
        promise =
          next: {}
          fulfill: (result) ->
            @next(result)
          then: (fn) ->
            @next = fn
        return promise
    describe 'for google', () ->
      session = {}
      userAttributes = {}
      accessToken = {}
      accessTokExtra = {}
      beforeEach (done) ->
        userAttributes =
          authenticated: true,
          id: '111111111111111111',
          name: 'David Jsa'
          given_name: 'David',
          email: 'kiesent@gmail.com',
          family_name: 'Jsa',
        accessToken = 'ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA'
        accessTokExtra = 
          token_type: 'Bearer',
          expires_in: 3600,
          id_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6ImNlMjNjZTgzOWE2YmU5ODdkMzhmNGM0YjU2NjQ1MDQyZjAxNThiYjYifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwidmVyaWZpZWRfZW1haWwiOiJ0cnVlIiwiaWQiOiIxMTQyNzczMjM1OTAzMzcxOTA3ODAiLCJhdWQiOiI1ODIzNjEwMDE5NjUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJjaWQiOiI1ODIzNjEwMDE5NjUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJlbWFpbCI6ImtpZXNlbnRAZ21haWwuY29tIiwidG9rZW5faGFzaCI6Im5wRklsU0d2Z0ZjSGpLSl9maHdCaHciLCJpYXQiOjEzNTMzNTg3ODAsImV4cCI6MTM1MzM2MjY4MH0.VKWx2FSVMtpozX3-ahd2vAIcAH-f2e8XUzdWJWp-nJQL6OlU0y2H031l42XY97e5juSuwhSpGMs_8y-ZAE8hecDAK4kaRJiHNCHW_G8qNzP3LSUPPVIRzaDTX0ZItQBGr8ddM0_taYuRo7eZk-duPZpIrgC4pk1oQUbesEHulDQ',
          refresh_token: '1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc'
        session = {}
        done()
      describe 'if there is no user in the session', () ->
        it 'should create a user from everyAuth and add the access tokens', (done) ->
          User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes)
            .then (user) ->
              expect(session.newUser).to.be.ok()
              expect(session.authUserData.given_name).to.be.ok()
              expect(user.auth.google.id).to.be '111111111111111111'
              expect(user.auth.google.aT).to.be 'ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA'
              expect(user.auth.google.rT).to.be '1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc'
              expect(user.auth.google.createdAt).to.be.ok()
              SocialUserData.findOne { _user: user._id }, (err, socialUserData) ->
                return done err  if err
                expect(socialUserData.google.userData.aTE.refresh_token).to.be '1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc'
                expect(socialUserData.google.userData.email).to.be 'kiesent@gmail.com'
                expect(socialUserData.google.userData.given_name).to.be 'David'
                expect(socialUserData.google.userData.family_name).to.be 'Jsa'
                done()
        it 'should find an existing user from everyAuth if there is no user in the session, and update access tokens', (done) ->
          userAttributes.id = '114277323590337190780'
          accessTokExtra.refresh_token = null
          User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.auth.google.id).to.be '114277323590337190780'
              expect(user.auth.google.aT).to.be 'ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA'
              expect(user.auth.google.rT).to.be 'iamarefreshtoken'
              done()
        it 'should return pre-existing user if pre-existing email connected', (done) ->
          userAttributes.email = 'google@gmail.com'
          accessTokExtra.refresh_token = null
          User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.auth.google.id).to.be '111111111111111111'
              expect(user.id).to.be '000000000000000000000003'
              done()
      describe 'if there is a user in the session', () ->
        beforeEach () ->
          session =
              auth:
                userId: '000000000000000000000004'
        it 'should link a google id', (done) ->
          userAttributes.id = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
          User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.id).to.be '000000000000000000000004'
              expect(user.auth.google.username).to.be('kiesent@gmail.com')
              expect(user.auth.google.id).to.be('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
              User.findById '000000000000000000000004', (err, user) ->
                expect(user.id).to.be '000000000000000000000004'
                expect(user.auth.google.username).to.be('kiesent@gmail.com')
                expect(user.auth.google.id).to.be('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
              done()
        it 'should not link a currently used google id', (done) ->
          userAttributes.id = '114277323590337190780'
          User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes)
            .then (err) ->
              expect(err).to.be.ok()
              expect(err.length).to.be(1)
              done()

    describe 'for facebook', () ->
      session = {}
      accessToken = {}
      accessTokExtra = {}
      fbUserMetaData = {}
      beforeEach (done) ->
        accessToken = 'AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD'
        accessTokExtra = 
          expires: '5183854'
        fbUserMetaData = 
          id: '2209612'
          name: 'David Jsa'
          first_name: 'David'
          last_name: 'Jsa'
          link: 'http://www.facebook.com/daviddjsa'
          username: 'daviddjsa'
          location: 
            id: '105479049486624'
            name: 'Ann Arbor Michigan'
          quotes: '"But Father not my will but yours be done." Jesus Christ'
          gender: 'male'
          timezone: -4
          locale: 'en_US'
          verified: true
          updated_time: '2012-10-16T01:30:42+0000'
        session = {}
        done()
      describe 'if there is no user in the session', () ->
        it 'should create a new user from everyAuth if this user does not previously exist in database', (done) ->
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (user) ->
              expect(session.authUserData.first_name).to.be.ok()
              expect(session.newUser).to.be.ok()
              expect(user.auth.facebook.id).to.be '2209612'
              expect(user.auth.facebook.username).to.be 'daviddjsa'
              expect(user.auth.facebook.aT).to.be 'AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD'
              expect(user.auth.facebook.createdAt).to.be.ok()
              SocialUserData.findOne { _user: user._id }, (err, socialUserData) ->
                return done err  if err
                expect(socialUserData.facebook.userData.first_name).to.be 'David'              
                fbUserMetaData.email = 'ddjsa@umich.edu'
                delete fbUserMetaData.gender
                User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
                  .then (user) ->
                    SocialUserData.findOne { _user: user._id }, (err, socialUserData) ->
                      expect(socialUserData.facebook.userData.gender).to.be('male')
                      expect(socialUserData.facebook.userData.email).to.be('ddjsa@umich.edu')
                      done()
        it 'should find an existing user from everyAuth if there is no user in the session and update access tokens', (done) ->
          fbUserMetaData.id = '198437102109342'
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.auth.facebook.id).to.be '198437102109342'
              expect(user.auth.facebook.aT).to.be 'AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD'
              done()
        it 'should find an existing user from everyAuth if there is no user in the session, and update cached data', (done) ->
          fbUserMetaData.id = '198437102109342'
          delete fbUserMetaData.first_name
          fbUserMetaData.last_name = 'Stone'
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              SocialUserData.findOne { _user: user._id }, (err, socialUserData) ->
                expect(socialUserData.facebook.userData.first_name).to.be 'Will'
                expect(socialUserData.facebook.userData.last_name).to.be 'Stone'
                done()
        it 'should return pre-existing user if pre-existing email connected', (done) ->
          fbUserMetaData.email = 'facebook@facebook.com'
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.auth.facebook.id).to.be '2209612'
              expect(user.auth.facebook.aT).to.be 'AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD'
              expect(user.id).to.be '000000000000000000000005'
              done()
      describe 'if there is a user in the session', () ->
        beforeEach () ->
          session =
            auth:
              userId: '000000000000000000000004'
        it 'should link a facebook id', (done) ->
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (user) ->
              expect(session.newUser).not.to.be.ok()
              expect(user.id).to.be '000000000000000000000004'
              expect(user.auth.facebook.username).to.be('daviddjsa')
              expect(user.auth.facebook.id).to.be('2209612')
              User.findById '000000000000000000000004', (err, user) ->
                expect(user.id).to.be '000000000000000000000004'
                expect(user.auth.facebook.username).to.be('daviddjsa')
                expect(user.auth.facebook.id).to.be('2209612')
              done()
        it 'should fail if user in session doesn\'t exist (how this would happen I have no idea)', (done) ->
          session.auth.userId = '999999999999999999999999'
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (err) ->
              expect(err).to.be.ok()
              expect(err.length).to.be(1)
              done()
        it 'should not link a currently used facebook id', (done) ->
          fbUserMetaData.id = '198437102109342'
          User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData)
            .then (err) ->
              expect(err).to.be.ok()
              expect(err.length).to.be(1)
              done()
