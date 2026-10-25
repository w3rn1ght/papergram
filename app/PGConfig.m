//
//  PGConfig.m
//  Papergram
//

#import "PGConfig.h"
#import "PGSecrets.h"

#import <UIKit/UIKit.h>

static NSString *const PGAPIIDKey = @"PGAPIID";
static NSString *const PGAPIHashKey = @"PGAPIHash";

@implementation PGConfig

+ (BOOL)hasCredentials
{
    return self.apiID > 0 && self.apiHash.length > 0;
}

+ (NSInteger)apiID
{
    NSInteger stored = [[NSUserDefaults standardUserDefaults] integerForKey:PGAPIIDKey];
    if (stored > 0) {
        return stored;
    }
    return (NSInteger)PG_BUILD_API_ID;
}

+ (NSString *)apiHash
{
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:PGAPIHashKey];
    if (stored.length > 0) {
        return stored;
    }
    return PG_BUILD_API_HASH;
}

+ (void)setAPIID:(NSInteger)apiID apiHash:(NSString *)apiHash
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:apiID forKey:PGAPIIDKey];
    [defaults setObject:(apiHash ?: @"") forKey:PGAPIHashKey];
    [defaults synchronize];
}

+ (NSString *)dataDirectory
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *base = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                              NSUserDomainMask,
                                                              YES) firstObject];
        path = [base stringByAppendingPathComponent:@"Papergram"];
        [[NSFileManager defaultManager] createDirectoryAtPath:path
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
    });
    return path;
}

+ (NSString *)applicationVersion
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length > 0 ? version : @"0.0.0";
}

+ (NSString *)deviceModel
{
    return [[UIDevice currentDevice] model] ?: @"iPad";
}

+ (NSString *)systemVersion
{
    return [NSString stringWithFormat:@"iOS %@", [[UIDevice currentDevice] systemVersion]];
}

+ (NSInteger)logVerbosity
{
    NSNumber *value = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PGLogVerbosity"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value.integerValue;
    }
    return 0;
}

@end
