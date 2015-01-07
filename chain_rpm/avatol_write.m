function avatol_write(det_results, output_dir, bb, pscore, part, state, samp)

write_det_res(det_results, bb, part, state, samp);
write_output(output_dir, pscore, part, state, samp);

%% helper functions
function write_det_res(det_results, bb, part, state, samp)

fsp = filesep;

x = (bb(1) + bb(3))/2;
y = (bb(2) + bb(4))/2;
h = samp.imsiz(1);
w = samp.imsiz(2);
x = x*100 / w;
y = y*100 / h;

file = [det_results fsp samp.id '_' part.id '.txt'];
fp = fopen(file, 'w');

content = [num2str(x) ',' num2str(y) ':' part.id ':' part.name ':' state.id ':' state.name '\n'];
fprintf(fp, content);

fclose(fp);


function write_output(output_dir, pscore, part, state, samp)

fsp = filesep;

[~,im,ext] = fileparts(samp.im);
im = ['media' fsp im ext];
sub_dir = strsplit(output_dir, 'output');
sub_dir = sub_dir{2};
det_file = ['detection_results' sub_dir fsp samp.id '_' part.id '.txt'];

file = [output_dir fsp 'sorted_output_data_' part.id '_' part.name '.txt'];
fp = fopen(file, 'a');

content = ['image_scored' '|' im '|' state.id '|' state.name '|' det_file '|' samp.tid '|1|' num2str(pscore) '\n'];
fprintf(fp, content);

fclose(fp);