/**
 * Authentication & OAuth Module
 *
 * Unified authentication module that provides:
 * - Session management
 * - OAuth 2.0 token operations
 * - Cookie utilities
 * - PKCE verification
 */

export {
  createSession,
  getSession,
  authenticateSession,
  storePendingAuthRequest,
  consumePendingAuthRequest,
  isAuthenticated,
  destroySession,
  type Session,
} from './session-manager.js';

export {
  createAuthorizationCode,
  exchangeCodeForToken,
  refreshAccessToken,
  validateAccessToken,
  revokeToken,
  validateClientCredentials,
} from './oauth-tokens.js';

export { getAuthStore, setAuthStore } from './auth-store-singleton.js';
export {
  createInMemoryAuthStore,
  createDynamoDbAuthStore,
  type DynamoDbAuthStoreOptions,
} from './auth-store.js';

export { generateSecureToken, verifyCodeChallenge } from './pkce.js';
