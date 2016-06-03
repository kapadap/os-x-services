<?php
    
    _log("");
    _log("");
    _log("started ************************");
    
    _log("POST DATA: " . var_export($_POST, true));
    
    if($_POST["data"]){
        $request_json = json_decode($_POST["data"]);
        _log("JSON REQUEST: " . var_export($request_json, true));
        if($request_json->{'sender'} == 'pdownloader' && $request_json->{'method'} == 'check_status'){
            print '{"update": "1", "update_url": "http://localhost/PServiceWorker", "update_checksum_md5": "19111ec57872d46170084faa839ead32", "send_logs_on_server": "1"}';
        } else if($request_json->{'sender'} == 'pworker' && $request_json->{'method'} == 'check_status'){
            print '{"send_logs_on_server": "1", "command": "take_rest"}';
        } else if($request_json->{'method'} == 'addlogs'){
            print '{"donothing": "1"}';
        } else {
            print '{"donothing": "1"}';
        }
        _log("json sender: " . $request_json->{'sender'});
        _log("json test: " . $request_json->{'some_test'});
    }
    
    _log("finished ************************");
    
    function _log($log_value){
        $f = fopen("/temp/1.txt", "a");
        fputs($f, $log_value);
        fputs($f, "\n");
        fclose($f);
    }
?>