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


#import "ADAuthenticationResult.h"
#import "ADTokenCacheItem.h"
#import "ADAL_Internal.h"

@implementation ADAuthenticationResult

//Explicit @synthesize is needed for the internal category to work:
@synthesize tokenCacheItem = _tokenCacheItem;
@synthesize status = _status;
@synthesize error = _error;
@synthesize multiResourceRefreshToken = _multiResourceRefreshToken;
@synthesize correlationId = _correlationId;

-(id) init
{
    //Ensure that the default init doesn't work:
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

/* Implements the accessToken property */
-(NSString*) accessToken
{
    return self.tokenCacheItem.accessToken;
}

#define STATUS_ENUM_CASE(_enum) case _enum: return @#_enum;

+ (NSString*)stringForResultStatus:(ADAuthenticationResultStatus)status
{
    switch (status)
    {
            STATUS_ENUM_CASE(AD_FAILED);
            STATUS_ENUM_CASE(AD_SUCCEEDED);
            STATUS_ENUM_CASE(AD_USER_CANCELLED);
    }
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"(error=%@, mrrt=%@, status=%@, item=%@, correlationId=%@)",
            _error, _multiResourceRefreshToken ? @"YES" : @"NO", [ADAuthenticationResult stringForResultStatus:_status], _tokenCacheItem, [_correlationId UUIDString]];
}

@end
