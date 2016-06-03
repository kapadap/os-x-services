#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "pmanager.h"

int main(int argc, const char * argv[]) {
    // show info and exit
    if(argc > 1){
        NSString* arg_2 = [NSString stringWithFormat:@"%s", argv[1]];
        if([arg_2 isEqualToString:@"v"] || [arg_2 isEqualToString:@"version"]){
            [[PManager VERSION] writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
        }
        return 0;
    }
    
    // obtain working folder path
    NSString* working_directory = [NSString stringWithFormat:@"%s", argv[0]];
    NSRange _indexof = [working_directory rangeOfString:@"/" options:NSBackwardsSearch | NSCaseInsensitiveSearch];
    working_directory = [working_directory substringToIndex:_indexof.location + 1];
    // initialize manager
    PManager* manager = [[PManager alloc] init];
    [manager setWorking_directory:working_directory];
    [manager setServer_end_point:@"http://localhost/pservice.php"];

    // working loop
    [manager log:@"Started *********************************" log_type:[PManager PLOG_MESSAGE]];
    [manager trace_info];
    while(![manager should_stop]){
        [manager manage_worker_service];
        // wait
        int wait_numnber = 100;
        while(![manager should_stop] && --wait_numnber >= 0){
            usleep(200000);
        }
    }
    
    [manager log:@"Finished *********************************" log_type:[PManager PLOG_MESSAGE]];
    return 0;
}