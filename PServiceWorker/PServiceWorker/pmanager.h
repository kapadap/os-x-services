#ifndef pmanager_h
#define pmanager_h

#import <Foundation/Foundation.h>

@interface PManager : NSObject
    +(NSString*)VERSION;
    /* PROPERTIES */
    @property NSString* working_directory;
    @property NSString* server_end_point;
    @property BOOL work_in_progress;
    @property BOOL send_logs_on_server;
    @property NSMutableArray* logs_for_server;
    @property NSLock* logs_for_server_lock;
    /* MANAGING */
    -(BOOL)should_stop;
    -(void)do_work;
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
