// Generated by CoffeeScript 1.3.3
(function() {
  var SocialReq, async, expect, mongoose, sinon, testConfig;

  expect = require('expect.js');

  sinon = require('sinon');

  mongoose = require('mongoose');

  require('coffee-script');

  testConfig = require('../testconfig');

  async = require('async');

  SocialReq = require('social-request');

  describe('Mongoose Social Plugin', function() {
    var SocialUserData, User, UserSchema, socialGetSpy, user;
    UserSchema = {};
    User = {};
    SocialUserData = {};
    user = {};
    socialGetSpy = {};
    before(function(done) {
      var socialReq;
      mongoose.connect('mongodb://localhost/mongoose-social-user-testing');
      socialReq = new SocialReq();
      socialGetSpy = sinon.spy(SocialReq.prototype, 'get', function(params, cb) {});
      UserSchema = new mongoose.Schema({
        name: String,
        email: String
      });
      UserSchema.plugin(require('../index.js'), {
        google: {
          clientId: testConfig.google.clientId,
          clientSecret: testConfig.google.clientSecret
        },
        facebook: {
          appId: testConfig.facebook.appId,
          appSecret: testConfig.facebook.appSecret
        },
        twitter: {
          consumerKey: testConfig.twitter.consumerKey,
          consumerSecret: testConfig.twitter.consumerSecret
        },
        linkedin: {
          apiKey: testConfig.linkedin.apiKey,
          secretKey: testConfig.linkedin.secretKey
        },
        mongoose: mongoose
      });
      User = mongoose.model('User', UserSchema);
      SocialUserData = mongoose.model('SocialUserData');
      return SocialUserData.remove(done);
    });
    beforeEach(function(done) {
      return async.parallel([
        function(cb) {
          return User.remove({}, cb);
        }, function(cb) {
          return SocialUserData.remove({}, cb);
        }
      ], function() {
        return async.parallel([
          function(cb) {
            return User.create([
              {
                _id: '000000000000000000000004'
              }, {
                _id: '000000000000000000000003',
                email: 'google@gmail.com',
                auth: {
                  google: {
                    id: '114277323590337190780',
                    aT: 'iamanaccesstoken',
                    rT: 'iamarefreshtoken'
                  }
                }
              }, {
                _id: '000000000000000000000005',
                email: 'facebook@facebook.com',
                auth: {
                  facebook: {
                    id: '198437102109342',
                    username: 'fbusername',
                    aT: 'iamasweetaccesstoken'
                  }
                }
              }, {
                _id: '000000000000000000000006',
                email: 'dude@gmail.com'
              }
            ], cb);
          }, function(cb) {
            return SocialUserData.create([
              {
                _user: '000000000000000000000005',
                facebook: {
                  userData: {
                    first_name: 'Will',
                    last_name: 'NotStone'
                  }
                }
              }
            ], cb);
          }
        ], done);
      });
    });
    after(function(done) {
      return User.remove({}, function() {
        return done();
      });
    });
    describe('installed', function() {
      return it('should add keys to user', function(done) {
        User = mongoose.model('User', UserSchema);
        user = new User();
        user.auth.facebook.id = 'abcd';
        user.auth.google.id = 'defg';
        user.auth.twitter.id = 'ghik';
        expect(user.auth.facebook.id).to.be('abcd');
        expect(user.auth.google.id).to.be('defg');
        expect(user.auth.twitter.id).to.be('ghik');
        return done();
      });
    });
    describe('#_invalidateAccessToken', function() {
      it('should invalidate an access token for oauth2 for a given service', function(done) {
        return User.findById('000000000000000000000003', function(err, user) {
          if (err) {
            throw err;
          }
          expect(user.auth.google.aT).to.be.ok();
          expect(user.auth.google.rT).to.be.ok();
          return user._invalidateAccessToken('google', function(err, user) {
            expect(user.auth.google.aT).not.to.be.ok();
            expect(user.auth.google.rT).to.be.ok();
            return done();
          });
        });
      });
      return it('should invalidate an access token for oauth for a given service');
    });
    describe('#_refreshAccessToken', function() {
      describe('for oauth2', function() {
        return describe('for google', function() {
          it('should refresh an access token', function(done) {
            this.timeout(10000);
            return User.findById('000000000000000000000003', function(err, user) {
              var oldAccessToken, oldRefreshToken;
              if (err) {
                throw err;
              }
              oldAccessToken = user.auth.google.aT;
              oldRefreshToken = user.auth.google.rT = testConfig.google.refresh_token;
              expect(user.auth.google.aT).to.be.ok();
              expect(user.auth.google.rT).to.be.ok();
              return user._refreshAccessToken('google', function(err, user) {
                if (err) {
                  throw err;
                }
                expect(user.auth.google.aT).to.be.ok();
                expect(user.auth.google.aT).not.to.be(oldAccessToken);
                expect(user.auth.google.rT).to.be.ok();
                expect(user.auth.google.rT).to.be(oldRefreshToken);
                return done();
              });
            });
          });
          it('should fail correctly if there is no refresh token', function(done) {
            return User.findById('000000000000000000000003', function(err, user) {
              if (err) {
                throw err;
              }
              user.auth.google.rT = null;
              return user._refreshAccessToken('google', function(err, user) {
                expect(err.message).to.be.ok();
                expect(err.code).to.be(400);
                return done();
              });
            });
          });
          return it('should send error information if refresh token is invalid', function(done) {
            return User.findById('000000000000000000000003', function(err, user) {
              if (err) {
                throw err;
              }
              user.auth.google.rT = 'failfailfail';
              return user._refreshAccessToken('google', function(err, user) {
                expect(err.message).to.be.ok();
                expect(err.code).to.be(400);
                return done();
              });
            });
          });
        });
      });
      return it('should refresh an access token for oauth for a given service');
    });
    describe('#getSocial', function() {
      describe('with correct access token', function() {
        return it('should get and cache the requested social data', function(done) {
          this.timeout(10000);
          return User.findById('000000000000000000000005', function(err, user) {
            if (err) {
              throw err;
            }
            user.auth.google.aT = testConfig.google.access_token;
            user.auth.google.rT = null;
            return user.getSocial({
              contacts: ['google'],
              details: ['google', 'googleplus']
            }, function(err, results) {
              if (err) {
                throw err;
              }
              expect(results.contacts.google.length).to.be.greaterThan(0);
              expect(socialGetSpy.calledWith('000000000000000000000005', {
                contacts: ['google'],
                details: ['google', 'googleplus']
              })).to.be.ok();
              expect(results.contacts.google.error).to.not.be.ok();
              return SocialUserData.findOne({
                _user: '000000000000000000000005'
              }, function(err, socialUserData) {
                if (err) {
                  throw err;
                }
                expect(socialUserData.google.contacts.length).to.be.greaterThan(0);
                expect(socialUserData.google.userData.name).to.be.ok();
                expect(socialUserData.google.userData.given_name).to.be.ok();
                expect(socialUserData.googleplus.userData.name.givenName).to.be.ok();
                return done();
              });
            });
          });
        });
      });
      return describe('with incorrect access token', function() {
        var userWithABadAccessToken;
        userWithABadAccessToken = null;
        beforeEach(function(done) {
          return User.findById('000000000000000000000005', function(err, user) {
            if (err) {
              throw err;
            }
            user.auth.google.aT = 'asdfasdfasdf';
            userWithABadAccessToken = user;
            return done();
          });
        });
        it('should try to refresh the access token with refresh token and request again', function(done) {
          this.timeout(10000);
          userWithABadAccessToken.auth.google.rT = testConfig.google.refresh_token;
          userWithABadAccessToken.auth.facebook.aT = testConfig.facebook.access_token;
          return userWithABadAccessToken.getSocial({
            contacts: ['google', 'facebook'],
            details: ['google', 'googleplus']
          }, function(err, results) {
            if (err) {
              throw err;
            }
            expect(results.contacts.google.length).to.be.greaterThan(0);
            expect(results.contacts.facebook.length).to.be.greaterThan(0);
            expect(socialGetSpy.calledWith('000000000000000000000005', {
              contacts: ['google', 'facebook'],
              details: ['google', 'googleplus']
            })).to.be.ok();
            expect(results.contacts.google.error).to.not.be.ok();
            return SocialUserData.findOne({
              _user: '000000000000000000000005'
            }, function(err, socialUserData) {
              if (err) {
                throw err;
              }
              expect(socialUserData.google.contacts.length).to.be.greaterThan(0);
              expect(socialUserData.google.userData.name).to.be.ok();
              expect(socialUserData.google.userData.given_name).to.be.ok();
              expect(socialUserData.googleplus.userData.name.givenName).to.be.ok();
              expect(socialUserData.facebook.contacts.length).to.be.greaterThan(0);
              return done();
            });
          });
        });
        it('should fail if service is not refreshable', function(done) {
          this.timeout(10000);
          delete userWithABadAccessToken.auth.google.aT;
          userWithABadAccessToken.auth.facebook.aT = 'wrongwrong';
          return userWithABadAccessToken.getSocial({
            contacts: ['facebook']
          }, function(err, results) {
            if (err) {
              throw err;
            }
            expect(results.contacts.facebook.error.message).to.be.ok();
            return done();
          });
        });
        it('should pass errors without a refresh token', function(done) {
          this.timeout(10000);
          delete userWithABadAccessToken.auth.google.rT;
          return userWithABadAccessToken.getSocial({
            contacts: ['google', 'facebook'],
            details: ['google']
          }, function(err, results) {
            if (err) {
              throw err;
            }
            expect(results.contacts.facebook.error.message).to.be.ok();
            expect(results.contacts.google.error.message).to.be.ok();
            expect(results.details.google.error.message).to.be.ok();
            return done();
          });
        });
        return it('should pass errors with a bad refresh token', function(done) {
          this.timeout(10000);
          userWithABadAccessToken.auth.google.rT = 'failfailfail';
          return userWithABadAccessToken.getSocial({
            contacts: ['google', 'facebook'],
            details: ['google']
          }, function(err, results) {
            if (err) {
              throw err;
            }
            expect(results.contacts.facebook.error.message).to.be.ok();
            expect(results.contacts.google.error.message).to.be.ok();
            expect(results.details.google.error.message).to.be.ok();
            return done();
          });
        });
      });
    });
    return describe('.findOrCreateUser', function() {
      var promiseScope;
      promiseScope = {
        Promise: function() {
          var promise;
          promise = {
            next: {},
            fulfill: function(result) {
              return this.next(result);
            },
            then: function(fn) {
              return this.next = fn;
            }
          };
          return promise;
        }
      };
      describe('for google', function() {
        var accessTokExtra, accessToken, session, userAttributes;
        session = {};
        userAttributes = {};
        accessToken = {};
        accessTokExtra = {};
        beforeEach(function(done) {
          userAttributes = {
            authenticated: true,
            id: '111111111111111111',
            name: 'David Jsa',
            given_name: 'David',
            email: 'kiesent@gmail.com',
            family_name: 'Jsa'
          };
          accessToken = 'ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA';
          accessTokExtra = {
            token_type: 'Bearer',
            expires_in: 3600,
            id_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6ImNlMjNjZTgzOWE2YmU5ODdkMzhmNGM0YjU2NjQ1MDQyZjAxNThiYjYifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwidmVyaWZpZWRfZW1haWwiOiJ0cnVlIiwiaWQiOiIxMTQyNzczMjM1OTAzMzcxOTA3ODAiLCJhdWQiOiI1ODIzNjEwMDE5NjUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJjaWQiOiI1ODIzNjEwMDE5NjUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJlbWFpbCI6ImtpZXNlbnRAZ21haWwuY29tIiwidG9rZW5faGFzaCI6Im5wRklsU0d2Z0ZjSGpLSl9maHdCaHciLCJpYXQiOjEzNTMzNTg3ODAsImV4cCI6MTM1MzM2MjY4MH0.VKWx2FSVMtpozX3-ahd2vAIcAH-f2e8XUzdWJWp-nJQL6OlU0y2H031l42XY97e5juSuwhSpGMs_8y-ZAE8hecDAK4kaRJiHNCHW_G8qNzP3LSUPPVIRzaDTX0ZItQBGr8ddM0_taYuRo7eZk-duPZpIrgC4pk1oQUbesEHulDQ',
            refresh_token: '1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc'
          };
          session = {};
          return done();
        });
        describe('if there is no user in the session', function() {
          it('should create a user from everyAuth and add the access tokens', function(done) {
            return User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes).then(function(user) {
              expect(session.newUser).to.be.ok();
              expect(session.authUserData.given_name).to.be.ok();
              expect(user.auth.google.id).to.be('111111111111111111');
              expect(user.auth.google.aT).to.be('ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA');
              expect(user.auth.google.rT).to.be('1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc');
              expect(user.auth.google.createdAt).to.be.ok();
              return SocialUserData.findOne({
                _user: user._id
              }, function(err, socialUserData) {
                if (err) {
                  throw err;
                }
                expect(socialUserData.google.userData.aTE.refresh_token).to.be('1/vioj8dHiZzxz7oK8wlEoIErBow0uno8-M4ky-ShwHhc');
                expect(socialUserData.google.userData.email).to.be('kiesent@gmail.com');
                expect(socialUserData.google.userData.given_name).to.be('David');
                expect(socialUserData.google.userData.family_name).to.be('Jsa');
                return done();
              });
            });
          });
          it('should find an existing user from everyAuth if there is no user in the session, and update access tokens', function(done) {
            userAttributes.id = '114277323590337190780';
            accessTokExtra.refresh_token = null;
            return User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.auth.google.id).to.be('114277323590337190780');
              expect(user.auth.google.aT).to.be('ya29.AHES6ZTbGtzk9pWGtw33ypFcf7B7RYn6zowhe1htQ9pFwnA');
              expect(user.auth.google.rT).to.be('iamarefreshtoken');
              return done();
            });
          });
          return it('should return pre-existing user if pre-existing email connected', function(done) {
            userAttributes.email = 'google@gmail.com';
            accessTokExtra.refresh_token = null;
            return User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.auth.google.id).to.be('111111111111111111');
              expect(user.id).to.be('000000000000000000000003');
              return done();
            });
          });
        });
        return describe('if there is a user in the session', function() {
          beforeEach(function() {
            return session = {
              auth: {
                userId: '000000000000000000000004'
              }
            };
          });
          it('should link a google id', function(done) {
            userAttributes.id = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
            return User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.id).to.be('000000000000000000000004');
              expect(user.auth.google.username).to.be('kiesent@gmail.com');
              expect(user.auth.google.id).to.be('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
              User.findById('000000000000000000000004', function(err, user) {
                expect(user.id).to.be('000000000000000000000004');
                expect(user.auth.google.username).to.be('kiesent@gmail.com');
                return expect(user.auth.google.id).to.be('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
              });
              return done();
            });
          });
          return it('should not link a currently used google id', function(done) {
            userAttributes.id = '114277323590337190780';
            return User.findOrCreateUser('google').bind(promiseScope)(session, accessToken, accessTokExtra, userAttributes).then(function(err) {
              expect(err).to.be.ok();
              expect(err.length).to.be(1);
              return done();
            });
          });
        });
      });
      return describe('for facebook', function() {
        var accessTokExtra, accessToken, fbUserMetaData, session;
        session = {};
        accessToken = {};
        accessTokExtra = {};
        fbUserMetaData = {};
        beforeEach(function(done) {
          accessToken = 'AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD';
          accessTokExtra = {
            expires: '5183854'
          };
          fbUserMetaData = {
            id: '2209612',
            name: 'David Jsa',
            first_name: 'David',
            last_name: 'Jsa',
            link: 'http://www.facebook.com/daviddjsa',
            username: 'daviddjsa',
            location: {
              id: '105479049486624',
              name: 'Ann Arbor Michigan'
            },
            quotes: '"But Father not my will but yours be done." Jesus Christ',
            gender: 'male',
            timezone: -4,
            locale: 'en_US',
            verified: true,
            updated_time: '2012-10-16T01:30:42+0000'
          };
          session = {};
          return done();
        });
        describe('if there is no user in the session', function() {
          it('should create a new user from everyAuth if this user does not previously exist in database', function(done) {
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
              expect(session.authUserData.first_name).to.be.ok();
              expect(session.newUser).to.be.ok();
              expect(user.auth.facebook.id).to.be('2209612');
              expect(user.auth.facebook.username).to.be('daviddjsa');
              expect(user.auth.facebook.aT).to.be('AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD');
              expect(user.auth.facebook.createdAt).to.be.ok();
              return SocialUserData.findOne({
                _user: user._id
              }, function(err, socialUserData) {
                if (err) {
                  throw err;
                }
                expect(socialUserData.facebook.userData.first_name).to.be('David');
                fbUserMetaData.email = 'ddjsa@umich.edu';
                delete fbUserMetaData.gender;
                return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
                  return SocialUserData.findOne({
                    _user: user._id
                  }, function(err, socialUserData) {
                    expect(socialUserData.facebook.userData.gender).to.be('male');
                    expect(socialUserData.facebook.userData.email).to.be('ddjsa@umich.edu');
                    return done();
                  });
                });
              });
            });
          });
          it('should find an existing user from everyAuth if there is no user in the session and update access tokens', function(done) {
            fbUserMetaData.id = '198437102109342';
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.auth.facebook.id).to.be('198437102109342');
              expect(user.auth.facebook.aT).to.be('AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD');
              return done();
            });
          });
          it('should find an existing user from everyAuth if there is no user in the session, and update cached data', function(done) {
            fbUserMetaData.id = '198437102109342';
            delete fbUserMetaData.first_name;
            fbUserMetaData.last_name = 'Stone';
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              return SocialUserData.findOne({
                _user: user._id
              }, function(err, socialUserData) {
                expect(socialUserData.facebook.userData.first_name).to.be('Will');
                expect(socialUserData.facebook.userData.last_name).to.be('Stone');
                return done();
              });
            });
          });
          return it('should return pre-existing user if pre-existing email connected', function(done) {
            fbUserMetaData.email = 'facebook@facebook.com';
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.auth.facebook.id).to.be('2209612');
              expect(user.auth.facebook.aT).to.be('AAAHOA4xnZBxMBAK4ZCI2PjnhqlMLhMd0aZA9lHpgPMwFN7rw6lOV5HBditZB5Hch2rFIdsNrQOR08qcR2ZAeZA5uAVzK2NNgQZD');
              expect(user.id).to.be('000000000000000000000005');
              return done();
            });
          });
        });
        return describe('if there is a user in the session', function() {
          beforeEach(function() {
            return session = {
              auth: {
                userId: '000000000000000000000004'
              }
            };
          });
          it('should link a facebook id', function(done) {
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(user) {
              expect(session.newUser).not.to.be.ok();
              expect(user.id).to.be('000000000000000000000004');
              expect(user.auth.facebook.username).to.be('daviddjsa');
              expect(user.auth.facebook.id).to.be('2209612');
              User.findById('000000000000000000000004', function(err, user) {
                expect(user.id).to.be('000000000000000000000004');
                expect(user.auth.facebook.username).to.be('daviddjsa');
                return expect(user.auth.facebook.id).to.be('2209612');
              });
              return done();
            });
          });
          it('should fail if user in session doesn\'t exist (how this would happen I have no idea)', function(done) {
            session.auth.userId = '999999999999999999999999';
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(err) {
              expect(err).to.be.ok();
              expect(err.length).to.be(1);
              return done();
            });
          });
          return it('should not link a currently used facebook id', function(done) {
            fbUserMetaData.id = '198437102109342';
            return User.findOrCreateUser('facebook').bind(promiseScope)(session, accessToken, accessTokExtra, fbUserMetaData).then(function(err) {
              expect(err).to.be.ok();
              expect(err.length).to.be(1);
              return done();
            });
          });
        });
      });
    });
  });

}).call(this);
