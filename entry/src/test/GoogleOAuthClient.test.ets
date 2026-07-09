import { describe, it, expect } from '@ohos/hypium';
import {
  buildGoogleOAuthAuthorizationUrl,
  buildGoogleRefreshTokenBody,
  buildGoogleTokenExchangeBody,
  parseGoogleOAuthRedirect
} from '@loop/agent-core';

export default function googleOAuthClientTest() {
  describe('googleOAuthClient', () => {
    it('builds Google OAuth URLs with caller-provided scopes and resource', 0, () => {
      const url = buildGoogleOAuthAuthorizationUrl({
        authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
        clientId: 'client-123.apps.googleusercontent.com',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        state: 'state-123',
        codeChallenge: 'challenge-456',
        scopes: 'https://www.googleapis.com/auth/youtube.readonly',
        resource: ''
      });

      expect(url.indexOf('https://accounts.google.com/o/oauth2/v2/auth?')).assertEqual(0);
      expect(url.indexOf('client_id=client-123.apps.googleusercontent.com')).assertLarger(-1);
      expect(url.indexOf('scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube.readonly')).assertLarger(-1);
      expect(url.indexOf('code_challenge=challenge-456')).assertLarger(-1);
      expect(url.indexOf('resource=')).assertEqual(-1);
    });

    it('builds token exchange and refresh form bodies', 0, () => {
      const exchange = buildGoogleTokenExchangeBody({
        clientId: 'client-123',
        clientSecret: 'secret-456',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        resource: ''
      }, 'auth-code', 'verifier-789');
      const refresh = buildGoogleRefreshTokenBody({
        clientId: 'client-123',
        clientSecret: '',
        redirectUri: 'com.example.aiphonedemo:/oauth/google',
        resource: ''
      }, 'refresh-token');

      expect(exchange.indexOf('grant_type=authorization_code')).assertLarger(-1);
      expect(exchange.indexOf('code=auth-code')).assertLarger(-1);
      expect(exchange.indexOf('client_secret=secret-456')).assertLarger(-1);
      expect(refresh.indexOf('grant_type=refresh_token')).assertLarger(-1);
      expect(refresh.indexOf('refresh_token=refresh-token')).assertLarger(-1);
      expect(refresh.indexOf('client_secret=')).assertEqual(-1);
    });

    it('parses OAuth redirects', 0, () => {
      const success = parseGoogleOAuthRedirect('com.example.aiphonedemo:/oauth/google?code=auth-code&state=state-123');
      const denied = parseGoogleOAuthRedirect('com.example.aiphonedemo:/oauth/google?error=access_denied&state=state-123');

      expect(success.ok).assertTrue();
      expect(success.code).assertEqual('auth-code');
      expect(success.state).assertEqual('state-123');
      expect(denied.ok).assertFalse();
      expect(denied.error).assertEqual('access_denied');
    });
  });
}
