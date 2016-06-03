#import "pmanager.h"

@implementation PManager

+(NSString*)VERSION {
    return @"1.0.0.1";
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [self setManaging_in_progress:NO];
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

-(BOOL)is_worker_service_running {
    NSArray<NSString*>* lines = [self execute_sh_cmd:@"launchctl" args:@"list | grep pservice.worker"];
    for (int i = 0; i < [lines count]; i++) {
        NSString* line = [lines[i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        NSArray<NSString*>* parts = [line componentsSeparatedByString:@"\t"];
        for (int j = 0; j < [parts count]; j++) {
            if([parts[j] isEqualToString:@"pservice.worker"])
                return YES;
        }
    }
    return NO;
}

-(void)stop_worker_service {
    NSArray<NSString*>* lines = [self execute_sh_cmd:@"launchctl" args:@"unload -w /Library/LaunchDaemons/pservice.worker.plist"];
    for (int i = 0; i < 50; i++) {
        if([self is_worker_service_running]){
            usleep(300000);
        } else break;
    }
    if([self is_worker_service_running]){
        if([lines count] > 0)
            [NSException raise:@"PException" format:@"Cannot stop worker service. %@", lines[0]];
        [NSException raise:@"PException" format:@"Cannot stop worker service"];
    }
}

-(void)start_worker_service {
    NSArray<NSString*>* lines = [self execute_sh_cmd:@"launchctl" args:@"load -w /Library/LaunchDaemons/pservice.worker.plist"];
    for (int i = 0; i < 50; i++) {
        if(![self is_worker_service_running]){
            usleep(300000);
        } else break;
    }
    if(![self is_worker_service_running]){
        if([lines count] > 0)
            [NSException raise:@"PException" format:@"Cannot start worker service. %@", lines[0]];
        [NSException raise:@"PException" format:@"Cannot start worker service"];
    }
}

-(int)get_worker_service_last_active_secs {
    NSString *path = [[self working_directory] stringByAppendingString:@"pservice.worker.last.active"];
    NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate* mod_date = [fileAttribs objectForKey:NSFileModificationDate];
    NSTimeInterval seconds = [mod_date timeIntervalSinceNow];
    return (int)fabs(seconds);
}

-(NSString*)get_worker_service_version:(NSString*)worker_service_path {
    NSArray<NSString*>* lines = [self execute_app:worker_service_path args:@"v"];
    if([lines count] > 0){
        return lines[0];
    }
    return @"-unknown-";
}

-(NSArray<NSString*>*)execute_app:(NSString*)app args:(NSString*)args {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = app;
    task.arguments = @[args];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSArray<NSString*>* lines = [grepOutput componentsSeparatedByString:@"\n"];
    return lines;
}

-(NSArray<NSString*>*)execute_sh_cmd:(NSString*)sh_command args:(NSString*)args {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = @[@"-c", [NSString stringWithFormat:@"%@ %@", sh_command, args]];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *grepOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSArray<NSString*>* lines = [grepOutput componentsSeparatedByString:@"\n"];
    return lines;
}

- (void)manage_worker_service
{
    if([self managing_in_progress])
        return;
    [self setManaging_in_progress:YES];
    // ...
    [self log:@"start managing worker service" log_type:[PManager PLOG_MESSAGE]];
    @try{
        NSString* current_worker_service_path = [NSString stringWithFormat:@"%@PServiceWorker", [self working_directory]];
        NSString* worker_version_current = [self get_worker_service_version:current_worker_service_path];
        [self log:[NSString stringWithFormat:@"Worker current app version: %@", worker_version_current] log_type:[PManager PLOG_MESSAGE]];
        int worker_service_last_active_secs = [self get_worker_service_last_active_secs];
        [self log:[NSString stringWithFormat:@"Worker service was last active %i seconds ago", worker_service_last_active_secs] log_type:[PManager PLOG_MESSAGE]];
        // restart working service if it's not responding
        if(worker_service_last_active_secs > 120){
            [self log:[NSString stringWithFormat:@"Restarting Worker service, due to it was last active more then %i seconds ago", worker_service_last_active_secs] log_type:[PManager PLOG_WARNING]];
            if([self is_worker_service_running]){
                [self stop_worker_service];
            }
            [self start_worker_service];
            [self log:@"Worker service has been restarted successfully" log_type:[PManager PLOG_MESSAGE]];
        }
        // request server status
        NSDictionary* json_request = @{@"sender": @"pdownloader", @"sender_guid": [self get_guid], @"method": @"check_status"};
        [self log:@"Verifying updates on server..." log_type:[PManager PLOG_MESSAGE]];
        [self call_server:json_request response_handler:^(NSString* response, NSString* error){
            @try {
                if([error length] > 0)
                    [NSException raise:@"PException" format:@"%@", error];
                [self log:[NSString stringWithFormat:@"Server response: %@", response] log_type:[PManager PLOG_MESSAGE]];
                NSDictionary* json_response = [PManager _json_parse:response];
                NSString* send_logs_on_server = json_response[@"send_logs_on_server"];
                [self setSend_logs_on_server:([send_logs_on_server isEqualToString:@"1"] ? YES : NO)];
                // update worker?
                NSString* update_url = json_response[@"update_url"];
                NSString* update_checksum_md5 = json_response[@"update_checksum_md5"];
                if([update_url length] > 0){
                    [self log:[NSString stringWithFormat:@"Start downloading update from : %@", update_url] log_type:[PManager PLOG_MESSAGE]];
                    // download new worker service
                    NSData* file_data = [NSData dataWithContentsOfURL:[NSURL URLWithString:update_url]];
                    NSString* downloaded_worker_service_path = [NSString stringWithFormat:@"%@new_pworker_service", [self working_directory]];
                    [file_data writeToFile:downloaded_worker_service_path atomically:YES];
                    [self log:@"download completed" log_type:[PManager PLOG_MESSAGE]];
                    // verify checksum
                    if([update_checksum_md5 length] > 0){
                        [self log:@"verifying checksum md5..." log_type:[PManager PLOG_MESSAGE]];
                        NSString* check_sum_md5_current = [self get_file_md5_checksum:downloaded_worker_service_path];
                        if(![update_checksum_md5 isEqualToString:check_sum_md5_current]){
                            [NSException raise:@"PException" format:@"Md5 checksum of downloaded file '%@' does not match to pattern '%@'", check_sum_md5_current, update_checksum_md5];
                        }
                        [self log:@"Checksums md5 matched" log_type:[PManager PLOG_MESSAGE]];
                    }
                    // stop worker service
                    if([self is_worker_service_running]){
                        [self log:@"Stopping worker service..." log_type:[PManager PLOG_MESSAGE]];
                        [self stop_worker_service];
                    }
                    [self log:@"Updating worker service file..." log_type:[PManager PLOG_MESSAGE]];
                    [file_data writeToFile:current_worker_service_path atomically:YES];
                    [self log:@"Starting worker service..." log_type:[PManager PLOG_MESSAGE]];
                    [self start_worker_service];
                    [self log:@"Working service has been updated successfully" log_type:[PManager PLOG_MESSAGE]];
                    NSString* worker_version_downloaded = [self get_worker_service_version:current_worker_service_path];
                    [self log:[NSString stringWithFormat:@"Worker new app version: %@", worker_version_downloaded] log_type:[PManager PLOG_MESSAGE]];
                }
            } @catch (NSException *_error) {
                [self log:[_error reason] log_type:[PManager PLOG_ERROR]];
            } @finally {
                [self setManaging_in_progress:NO];
            }
        }];
        // wait until all management completed
        while([self managing_in_progress]){
            usleep(200000);
        }
    } @catch(NSException* _error){
        [self  log:[_error reason]log_type:[PManager PLOG_ERROR]];
    } @finally {
        [self log:@"finish managing worker service" log_type:[PManager PLOG_MESSAGE]];
        [self setManaging_in_progress:NO];
    }
}

-(NSString*)get_file_md5_checksum:(NSString*)file_path {
    NSArray<NSString*>* lines = [self execute_sh_cmd:@"md5" args:file_path];
    if(![lines count]){
        [NSException raise:@"PException" format:@"Can't calculate md5. No cmd output"];
    }
    NSArray<NSString*>* parts = [lines[0] componentsSeparatedByString:@"="];
    if([parts count] != 2){
        [NSException raise:@"PException" format:@"Can't calculate md5. Invalid cmd output"];
    }
    return [parts[1] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
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
        NSString* guid_file_path = [NSString stringWithFormat:@"%@/guid_pservice_downloader", [self working_directory]];
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
        return [[self working_directory] stringByAppendingString:@"pdownloader_log_warning.log"];
    } else if(log_type == [PManager PLOG_ERROR]){
        return [[self working_directory] stringByAppendingString:@"pdownloader_log_error.log"];
    }
    return [[self working_directory] stringByAppendingString:@"pdownloader_log_all.log"];
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