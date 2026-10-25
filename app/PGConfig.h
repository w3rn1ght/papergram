//
//  PGConfig.h
//  Papergram
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runtime configuration and paths.
///
/// Credentials are resolved in this order:
///   1. Values entered by the user in the setup screen (NSUserDefaults).
///   2. Values baked in at build time from CI secrets (PGSecrets.h).
@interface PGConfig : NSObject

+ (BOOL)hasCredentials;
+ (NSInteger)apiID;
+ (NSString *)apiHash;
+ (void)setAPIID:(NSInteger)apiID apiHash:(NSString *)apiHash;

+ (NSString *)dataDirectory;
+ (NSString *)applicationVersion;

+ (NSString *)deviceModel;
+ (NSString *)systemVersion;

/// 0 = errors only. Useful when debugging transport problems.
+ (NSInteger)logVerbosity;

@end

NS_ASSUME_NONNULL_END
