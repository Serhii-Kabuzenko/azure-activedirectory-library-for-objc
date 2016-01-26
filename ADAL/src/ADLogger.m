// Copyright © Microsoft Open Technologies, Inc.
//
// All Rights Reserved
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
// ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A
// PARTICULAR PURPOSE, MERCHANTABILITY OR NON-INFRINGEMENT.
//
// See the Apache License, Version 2.0 for the specific language
// governing permissions and limitations under the License.

#import "ADAL_Internal.h"
#import "ADOAuth2Constants.h"
#import "ADLogger+Internal.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/machine.h>
#include <CommonCrypto/CommonDigest.h>

static ADAL_LOG_LEVEL s_LogLevel = ADAL_LOG_LEVEL_ERROR;
static LogCallback s_LogCallback = nil;
static BOOL s_NSLogging = YES;
static NSUUID* s_requestCorrelationId;

static NSMutableDictionary* s_adalId = nil;

static dispatch_once_t s_logOnce;

@implementation ADLogger

+ (void)setLevel:(ADAL_LOG_LEVEL)logLevel
{
    s_LogLevel = logLevel;
}

+ (ADAL_LOG_LEVEL)getLevel
{
    return s_LogLevel;
}

+ (void)setLogCallBack:(LogCallback)callback
{
    @synchronized(self)//Avoid changing to null while attempting to call it.
    {
        s_LogCallback = [callback copy];
    }
}


+ (void)setNSLogging:(BOOL)nslogging
{
    s_NSLogging = nslogging;
}

+ (BOOL)getNSLogging
{
    return s_NSLogging;
}

@end

@implementation ADLogger (Internal)

+ (LogCallback)getLogCallBack
{
    @synchronized(self)
    {
        return s_LogCallback;
    }
}

+ (NSString*)formatStringPerLevel:(ADAL_LOG_LEVEL)level
{
    {//Compile time check that all of the levels are covered below.
    int add_new_types_to_the_switch_below_to_fix_this_error[ADAL_LOG_LEVEL_VERBOSE - ADAL_LOG_LAST];
    #pragma unused(add_new_types_to_the_switch_below_to_fix_this_error)
    }
    
    switch (level) {
        case ADAL_LOG_LEVEL_ERROR:
            return @"ADALiOS [%@ - %@] ERROR: %@. Additional Information: %@. ErrorCode: %d.";
            break;
            
        case ADAL_LOG_LEVEL_WARN:
            return @"ADALiOS [%@ - %@] WARNING: %@. Additional Information: %@. ErrorCode: %d.";
            break;
            
        case ADAL_LOG_LEVEL_INFO:
            return @"ADALiOS [%@ - %@] INFORMATION: %@. Additional Information: %@. ErrorCode: %d.";
            break;
            
        case ADAL_LOG_LEVEL_VERBOSE:
            return @"ADALiOS [%@ - %@] VERBOSE: %@. Additional Information: %@. ErrorCode: %d.";
            break;
            
        default:
            return @"ADALiOS [%@ - %@] UNKNOWN: %@. Additional Information: %@. ErrorCode: %d.";
            break;
    }
}

+ (void)log:(ADAL_LOG_LEVEL)logLevel
    message:(NSString*)message
  errorCode:(NSInteger)errorCode
       info:(NSString*)info
correlationId:(NSUUID*)correlationId
{
    //Note that the logging should not throw, as logging is heavily used in error conditions.
    //Hence, the checks below would rather swallow the error instead of throwing and changing the
    //program logic.
    if (logLevel <= ADAL_LOG_LEVEL_NO_LOG)
        return;
    if (!message)
        return;
    
    @synchronized(self)//Guard against thread-unsafe callback and modification of sLogCallback after the check
    {
        if (logLevel <= s_LogLevel)
        {
            NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            if (s_NSLogging)
            {
                //NSLog is documented as thread-safe:
                NSLog([self formatStringPerLevel:logLevel], [dateFormatter stringFromDate:[NSDate date]], correlationId?[correlationId UUIDString]:@"", message, info, errorCode);
            }
            
            if (s_LogCallback)
            {
                if (correlationId)
                {
                    s_LogCallback(logLevel, [NSString stringWithFormat:@"ADALiOS [%@ - %@] %@", [dateFormatter stringFromDate:[NSDate date]], [correlationId UUIDString], message], info, errorCode);
                }
                else
                {
                    s_LogCallback(logLevel, [NSString stringWithFormat:@"ADALiOS [%@] %@", [dateFormatter stringFromDate:[NSDate date]], message], info, errorCode);
                }
            }
        }
    }
}

+ (void)log:(ADAL_LOG_LEVEL)level
    message:(NSString*)message
  errorCode:(NSInteger)code
correlationId:(NSUUID*)correlationId
     format:(NSString*)format, ...
{
    va_list args;
    va_start(args, format);
    NSString* info = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self log:level message:message errorCode:code info:info correlationId:correlationId];
}

//Extracts the CPU information according to the constants defined in
//machine.h file. The method prints minimal information - only if 32 or
//64 bit CPU architecture is being used.
+ (NSString*)getCPUInfo
{
    size_t structSize;
    cpu_type_t cpuType;
    structSize = sizeof(cpuType);
    
    //Extract the CPU type. E.g. x86. See machine.h for details
    //See sysctl.h for details.
    int result = sysctlbyname("hw.cputype", &cpuType, &structSize, NULL, 0);
    if (result)
    {
        AD_LOG_WARN_F(@"Logging", nil, @"Cannot extract cpu type. Error: %d", result);
        return nil;
    }
    
    return (CPU_ARCH_ABI64 & cpuType) ? @"64" : @"32";
}

+ (NSDictionary*)adalId
{
    dispatch_once(&s_logOnce, ^{
        UIDevice* device = [UIDevice currentDevice];
        s_adalId = [NSMutableDictionary dictionaryWithDictionary:
                    @{
                      ADAL_ID_PLATFORM:@"iOS",
                      ADAL_ID_VERSION:[ADLogger getAdalVersion],
                      ADAL_ID_OS_VER:device.systemVersion,
                      ADAL_ID_DEVICE_MODEL:device.model,//Prints out only "iPhone" or "iPad".
                      }];
        NSString* CPUVer = [self getCPUInfo];
        if (![NSString adIsStringNilOrBlank:CPUVer])
        {
            [s_adalId setObject:CPUVer forKey:ADAL_ID_CPU];
        }
    });
    
    return s_adalId;
}

+ (NSString*)getHash:(NSString*)input
{
    if (!input)
    {
        return nil;//Handle gracefully
    }
    const char* inputStr = [input UTF8String];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(inputStr, (int)strlen(inputStr), hash);
    NSMutableString* toReturn = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH*2];
    for (int i = 0; i < sizeof(hash)/sizeof(hash[0]); ++i)
    {
        [toReturn appendFormat:@"%02x", hash[i]];
    }
    return toReturn;
}

+ (NSString*) getAdalVersion
{
    return ADAL_VERSION_NSSTRING;
}

+ (void)logToken:(NSString*)token
       tokenType:(NSString*)tokenType
       expiresOn:(NSDate*)expiresOn
   correlationId:(NSUUID*)correlationId
{
    AD_LOG_VERBOSE_F(@"Token returned", nil, @"Obtained %@ with hash %@, expiring on %@ and correlationId: %@", tokenType, [self getHash:token], expiresOn, [correlationId UUIDString]);
}

+ (void)setIdValue:(NSString*)value
            forKey:(NSString*)key
{
    [self adalId];
    
    [s_adalId setObject:value forKey:key];
}

@end
