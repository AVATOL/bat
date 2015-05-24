function invoke_batskull_system(pathToSummaryFile, regimeChoice)

if nargin == 0
    input_dir = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/input/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    output_dir = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/output/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
    det_results = '/home/hushell/working/git-dir/avatol_cv/matrix_downloads/BAT/detection_results/DPM/c427749c427751c427753c427754c427760/v3540/split_0.7/';
end

% root dir
rt_dir = strsplit(pathToSummaryFile, 'input');
rt_dir = rt_dir{1};

% read summary.txt 
fp = fopen(pathToSummaryFile, 'r');
while 1
    tline = fgetl(fp);
    if ~ischar(tline)
        break
    end

    strs = strsplit(tline, ',');

    if strcmp(strs{1},'character')
        continue
    elseif strcmp(strs{1},'media')
        continue
    elseif strcmp(strs{1},'state')
        continue
    elseif strcmp(strs{1},'taxon')
        continue
    elseif strcmp(strs{1},'view')
        continue
    elseif strcmp(strs{1},'inputDir')
        input_dir = [rt_dir strs{2}]; 
    elseif strcmp(strs{1},'outputDir')
        output_dir = [rt_dir strs{2}]; 
    elseif strcmp(strs{1},'detectionResultsDir')
        det_results = [rt_dir strs{2}]; 
    else
        error('summary.txt: unknown line');
    end
end
fclose(fp);

% Change the current folder to the folder of this m-file.
if(~isdeployed)
    want_to_go = fileparts(which('avatol_main.m'));
    where_we_are = cd(want_to_go);
    fprintf('*** now we cd to %s\n', want_to_go); 

    if strcmp(regimeChoice, 'regime2')
        avatol_main(input_dir, output_dir, det_results); 
    elseif strcmp(regimeChoice, 'regime1')
        disp('regime1 is deprecated!');
    else
        disp('unknown regime!');
    end

    cd(where_we_are);
    fprintf('*** now we back to %s\n', where_we_are); 
else
    if strcmp(regimeChoice, 'regime2')
        avatol_main(input_dir, output_dir, det_results); 
    elseif strcmp(regimeChoice, 'regime1')
        disp('regime1 is deprecated!');
    else
        disp('unknown regime!');
    end
end

