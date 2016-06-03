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
        report_memory(manager);
        [manager do_work];
        // wait
        int wait_numnber = 100;
        while(![manager should_stop] && --wait_numnber >= 0){
            usleep(200000);
        }
    }
    
    [manager log:@"Finished *********************************" log_type:[PManager PLOG_MESSAGE]];
    return 0;
}

NSDate* report_memory_started = nil;
vm_size_t report_memory_initial_mem_kb = 0;

int report_memory(PManager* manager) {
    @try {
        NSTimeInterval seconds_elapsed = 0.0;
        if(!report_memory_started){
            report_memory_started = [NSDate dateWithTimeIntervalSinceNow:0];
        }
        struct task_basic_info info;
        mach_msg_type_number_t size = sizeof(info);
        kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
        if( kerr == KERN_SUCCESS ) {
            NSTimeInterval elapsed_hours = floor(seconds_elapsed / (60.0 * 60.0));
            NSTimeInterval elapsed_minutes = floor((seconds_elapsed - elapsed_hours * 60.0 * 60.0) / 60.0);
            vm_size_t memusage_kb = (vm_size_t)(info.resident_size / 1000);
            if(!report_memory_initial_mem_kb)
            report_memory_initial_mem_kb = memusage_kb;
            vm_size_t memusage_diff_kb = memusage_kb - report_memory_initial_mem_kb;
            NSString* memusage_diff_sign = (memusage_diff_kb > 0 ? @"+" : @"");
            [manager log:[NSString stringWithFormat:@"MEMUSE: %lu kb (%@%lu kb since %i:%i)", memusage_kb, memusage_diff_sign, memusage_diff_kb, (int)elapsed_hours, (int)elapsed_minutes] log_type:[PManager PLOG_MESSAGE]];
            return 0;
        } else {
            [manager log:[NSString stringWithFormat:@"ERRO MEMUSE: %s", mach_error_string(kerr)] log_type:[PManager PLOG_WARNING]];
        }
    } @catch (NSException *exception) {
        
    }
    return 1;
}