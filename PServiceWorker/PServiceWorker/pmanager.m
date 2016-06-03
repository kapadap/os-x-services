#import "pmanager.h"

@implementation PManager

+(NSString*)VERSION {
    return @"1.0.0.2";
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self setWork_in_progress:NO];
        [self setSend_logs_on_server:NO];
        [self setLogs_for_server:[[NSMutableArray alloc] init]];
        [self setLogs_for_server_lock:[[NSLock alloc] init]];
    }
    return self;
}

-(BOOL)should_stop
{
    return NO;
}

-(void)do_work{
    if([self work_in_progress])
        return;
    [self setWork_in_progress:YES];
    [self log:@"Start work" log_type:[PManager PLOG_MESSAGE]];
    @try {
        // notify about itself
        NSString* im_alive_file_path = [[self working_directory] stringByAppendingString:@"pservice.worker.last.active"];
        NSString* _empty = @"1";
        [_empty writeToFile:im_alive_file_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        // now do something usefull
    } @catch (NSException *_error) {
        [self log:[_error reason] log_type:[PManager PLOG_ERROR]];
    } @finally {
        [self log:@"Done work" log_type:[PManager PLOG_MESSAGE]];
        [self setWork_in_progress:NO];
    }
}

-(void)call_server:(NSDictionary*)request response_handler:(void(^)(NSString* response, NSString* error))response_handler
{
    NSURL *URL = [NSURL URLWithString:[self server_end_point]];
    NSMutableURLRequest *http_request = [NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10];
    [http_request setHTTPMethod:@"POST"];
    [http_request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString* json_request = [PManager _json_stringify:request];
    NSString* post_data_str = [NSString stringWithFormat:@"data=%@", json_request];
    [http_request setHTTPBody:[post_data_str dataUsingEncoding: NSUTF8StringEncoding]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:http_request completionHandler:
                                  ^(NSData *http_response_data, NSURLResponse *http_response, NSError *http_error) {
                                      @try {
                                          if(http_error){
                                              response_handler(nil, [http_error description]);
                                          } else {
                                              NSString* http_reponse_str = [[NSString alloc] initWithData:http_response_data encoding: NSUTF8StringEncoding];
                                              response_handler(http_reponse_str, @"");
                                          }
                                      } @catch (NSException *_error) {
                                          response_handler(nil, [_error reason]);
                                      }
                                  }];
    [task resume];
}

-(NSString*)get_guid
{
    NSString *guid = @"";
    @try {
        NSString* guid_file_path = [NSString stringWithFormat:@"%@/guid_pservice_worker", [self working_directory]];
        NSFileManager* file_manager = [NSFileManager defaultManager];
        NSError* ferror = nil;
        // load generated gui from file if any
        if([file_manager fileExistsAtPath:guid_file_path]){
            guid = [NSString stringWithContentsOfFile:guid_file_path encoding:NSUTF8StringEncoding error:&ferror];
            if(ferror){
                [NSException raise:@"PException" format:@"%@", [ferror description]];
            }
        } else {
            // generate new guid and save it to file
            guid = [[NSUUID UUID] UUIDString];
            [guid writeToFile:guid_file_path atomically:YES encoding:NSUTF8StringEncoding error:&ferror];
            if(ferror){
                [NSException raise:@"PException" format:@"%@", [ferror description]];
            }
        }
    } @catch (NSException *_error) {
        [self log:[NSString stringWithFormat:@"Failed to create GUID. %@", _error] log_type:[PManager PLOG_ERROR]];
    }
    return guid;
}

+(NSDictionary*)_json_parse:(NSString*)json_serialized_string
{
    NSData *json_test_data = [json_serialized_string dataUsingEncoding:NSUTF8StringEncoding];
    NSError *json_parse_error = nil;
    NSDictionary *json_obj = [NSJSONSerialization JSONObjectWithData: json_test_data options:NSJSONReadingMutableContainers error: &json_parse_error];
    if(json_parse_error){
        [NSException raise:@"PException" format:@"Cannot parse json string '%@'. %@", json_serialized_string, [json_parse_error description]];
    }
    if(!json_obj){
        [NSException raise:@"PException" format:@"Cannot parse json string '%@'", json_serialized_string];
    }
    return json_obj;
}

+(NSString*)_json_stringify:(NSDictionary*)json
{
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:json options:kNilOptions error:&error];
    if(error){
        [NSException raise:@"PException" format:@"%@", [error description]];
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

/* LOGGER ****************************************************************************** */

+ (int) PLOG_MESSAGE { return 1; }

+ (int) PLOG_WARNING { return 2; }

+ (int) PLOG_ERROR { return 3; }

-(void)trace_info
{
    // log info
    [self _trace:[NSString stringWithFormat:@"Log all at: %@", [self _get_log_file_path:[PManager PLOG_MESSAGE]]] log_type:[PManager PLOG_MESSAGE]];
    [self _trace:[NSString stringWithFormat:@"Log warnings at: %@", [self _get_log_file_path:[PManager PLOG_WARNING]]] log_type:[PManager PLOG_MESSAGE]];
    [self _trace:[NSString stringWithFormat:@"Log errors at: %@", [self _get_log_file_path:[PManager PLOG_ERROR]]] log_type:[PManager PLOG_MESSAGE]];
    // info
    [self log:[NSString stringWithFormat:@"Version: %@", [PManager VERSION]] log_type:[PManager PLOG_MESSAGE]];
    [self log:[NSString stringWithFormat:@"GUID: %@", [self get_guid]] log_type:[PManager PLOG_MESSAGE]];
    [self log:[NSString stringWithFormat:@"Working directory: %@", [self working_directory]] log_type:[PManager PLOG_MESSAGE]];
    [self log:[NSString stringWithFormat:@"Server endpoint: %@", [self server_end_point]] log_type:[PManager PLOG_MESSAGE]];
}

-(void)log:(NSString *)value log_type:(int)log_type
{
    @try{
        [self _trace:value log_type:log_type];
        // log to file
        if([[self working_directory] isEqualToString:@""]){
            [NSException raise:@"PException" format:@"Cannot log to file. Working directory is not defined"];
        }
        NSString* log_path_all = [self _get_log_file_path:[PManager PLOG_MESSAGE]];
        NSString* log_path_current = [self _get_log_file_path:log_type];
        // adjust log value
        NSString* _log_prefix = @"M";
        if(log_type == [PManager PLOG_WARNING])
            _log_prefix = @"W";
        else if(log_type == [PManager PLOG_ERROR])
            _log_prefix = @"E";
        NSDate* date_now = [NSDate dateWithTimeIntervalSinceNow:0];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSString* log_data = [NSString stringWithFormat:@"[%@] [%@] %@", [dateFormatter stringFromDate: date_now], _log_prefix, value];
        // write to file
        [self append_line_to_file:log_path_all text:log_data];
        if(![log_path_all isEqualToString:log_path_current]){
            [self append_line_to_file:log_path_current text:log_data];
        }
        // send logs to server
        [[self logs_for_server_lock] lock];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        NSDictionary* log_obj = @{@"type": _log_prefix, @"date": [dateFormatter stringFromDate: date_now], @"text": value};
        [[self logs_for_server] addObject:log_obj];
        if([[self logs_for_server] count] > 30){
            NSDictionary* json_request = @{@"sender": @"pdownloader", @"sender_guid": [self get_guid], @"method": @"addlogs", @"logs": [[self logs_for_server] copy]};
            [[self logs_for_server] removeAllObjects];
            if([self send_logs_on_server]){
                [self call_server:json_request response_handler:^(NSString* response, NSString* error){}];
            }
        }
        [[self logs_for_server_lock] unlock];
    }
    @catch(NSException* _error){
        [self _trace:[NSString stringWithFormat:@"Can't write to log file. %@", [_error reason]] log_type:[PManager PLOG_ERROR]];
    }
}

-(NSString*)_get_log_file_path:(int)log_type
{
    if(log_type == [PManager PLOG_WARNING]){
        return [[self working_directory] stringByAppendingString:@"pworker_log_warning.log"];
    } else if(log_type == [PManager PLOG_ERROR]){
        return [[self working_directory] stringByAppendingString:@"pworker_log_error.log"];
    }
    return [[self working_directory] stringByAppendingString:@"pworker_log_all.log"];
}

-(void)_trace:(NSString *)value log_type:(int)log_type
{
    @try{
        if(log_type == [PManager PLOG_MESSAGE]){
            NSLog(@"MESSAGE: %@", value);
        } else if(log_type == [PManager PLOG_WARNING]){
            NSLog(@"WARNING: %@", value);
        } else if(log_type == [PManager PLOG_ERROR]){
            NSLog(@"ERROR: %@", value);
        }
    }
    @catch(NSException* _error){
        
    }
}

-(void)append_line_to_file:(NSString *)file_path text:(NSString *)text
{
    @try{
        NSFileManager* file_manager = [NSFileManager defaultManager];
        if(![file_manager fileExistsAtPath:file_path]){
            NSString* str = @"";
            [str writeToFile:file_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
        NSFileHandle* file_ptr = [NSFileHandle fileHandleForWritingAtPath:file_path];
        [file_ptr seekToEndOfFile];
        [file_ptr writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];
        [file_ptr writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [file_ptr closeFile];
    }
    @catch(NSException* _error){
        [self _trace:[NSString stringWithFormat:@"Cant write file. %@", [_error reason]] log_type:[PManager PLOG_ERROR]];
    }
}

@end