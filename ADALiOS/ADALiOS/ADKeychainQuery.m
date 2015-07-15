//
//  ADKeychainQuery.m
//  ADALiOS
//
//  Created by Ryan Pangrle on 7/12/15.
//  Copyright (c) 2015 MS Open Tech. All rights reserved.
//

#import "ADKeychainQuery.h"
#import "ADUserInformation.h"

@implementation ADKeychainQuery

- (id)init
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _cfmdKeychainQuery = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(_cfmdKeychainQuery, kSecClass, kSecClassGenericPassword);
    
    return self;
}

- (void)dealloc
{
    CFRelease(_cfmdKeychainQuery);
}

- (void)setServiceKey:(NSString*)serviceKey
{
    CFDictionaryAddValue(_cfmdKeychainQuery, kSecAttrService, (__bridge const void *)(serviceKey));
}

- (void)setAccessGroup:(NSString*)accessGroup
{
    if (!accessGroup)
    {
        return;
    }
    
    CFDictionaryAddValue(_cfmdKeychainQuery, kSecAttrAccessGroup, (__bridge const void *)(accessGroup));
}

- (void)setCopyData
{
    CFDictionaryAddValue(_cfmdKeychainQuery, kSecReturnData, kCFBooleanTrue);
}

- (void)setUserId:(NSString *)userId
{
    userId = [ADUserInformation normalizeUserId:userId];
    CFDictionaryAddValue(_cfmdKeychainQuery, kSecAttrAccount, (__bridge const void *)(userId));
}

- (CFDictionaryRef)queryDictionary
{
    return (CFDictionaryRef)_cfmdKeychainQuery;
}

@end
