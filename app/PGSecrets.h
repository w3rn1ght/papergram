//
//  PGSecrets.h
//  Papergram
//
//  Build-time API credentials. The CI pipeline overwrites this file with
//  values from repository secrets; the committed version is intentionally
//  empty so that a fresh checkout still builds and asks for credentials
//  at runtime.
//

#ifndef PGSecrets_h
#define PGSecrets_h

#ifndef PG_BUILD_API_ID
#define PG_BUILD_API_ID 0
#endif

#ifndef PG_BUILD_API_HASH
#define PG_BUILD_API_HASH @""
#endif

#endif /* PGSecrets_h */
