#ifndef pmanager_h
#define pmanager_h

#import <Foundation/Foundation.h>

@interface PManager : NSObject
    +(NSString*)VERSION;
    /* PROPERTIES */
    @property NSString* working_directory;
    @property NSString* server_end_point;
    @property BOOL managing_in_progress;
    @property BOOL send_logs_on_server;
    @property NSMutableArray* logs_for_server;
    @property NSLock* logs_for_server_lock;
    /* MANAGING */
    -(void)manage_worker_service;
    -(NSString*)get_guid;
    -(BOOL)should_stop;
    -(BOOL)is_worker_service_running;
    -(void)stop_worker_service;
    -(void)start_worker_service;
    -(int)get_worker_service_last_active_secs;
    -(NSString*)get_worker_service_version:(NSString*)worker_service_path;
    /* OTHER */
    -(NSArray<NSString*>*)execute_app:(NSString*)app args:(NSString*)args;
    -(NSArray<NSString*>*)execute_sh_cmd:(NSString*)sh_command args:(NSString*)args;
    -(NSString*)get_file_md5_checksum:(NSString*)file_path;
    /* HTTP */
    -(void)call_server:(NSDictionary*)request response_handler:(void(^)(NSString* response, NSString* error))response_handler;
    /* JSON */
    +(NSString*)_json_stringify:(NSDictionary*)json;
    +(NSDictionary*)_json_parse:(NSString*)json_serialized_string;
    /* LOGGER */
    + (int) PLOG_MESSAGE;
    + (int) PLOG_WARNING;
    + (int) PLOG_ERROR;
    - (NSString*)_get_log_file_path:(int)log_type;
    - (void)_trace:(NSString*)value log_type: (int)log_type;
    - (void)trace_info;
    - (void)log:(NSString*)value log_type: (int)log_type;
    - (void)append_line_to_file:(NSString*)file_path text: (NSString*)text;
@end

#endif /* pmanager_h */
