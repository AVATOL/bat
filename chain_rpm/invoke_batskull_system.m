function invoke_batskull_system(list_of_characters, input_dir, output_dir, ...
    det_results, progress_indicator)

if nargin == 0
    input_dir = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/input/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    output_dir = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/output/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    det_results = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/detection_results/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
end

% Change the current folder to the folder of this m-file.
if(~isdeployed)
    want_to_go = fileparts(which('avatol_main.m'));
    where_we_are = cd(want_to_go);
    fprintf('*** now we cd to %s\n', want_to_go); 
end

avatol_main(input_dir, output_dir, det_results); % regime 2

cd(where_we_are);
fprintf('*** now we back to %s\n', where_we_are); 
