function boxes = test_on_warped(model, test_path, src_path, numparts, colorset, display)
%% testing on warped images
% display = 1;
% test_path = '/home/hushell/working/AVATOL/datasets/Bat/vent_exp_transfer_resized/Molossus_from_A/';
% src_path = '/home/hushell/working/AVATOL/datasets/Bat/vent_exp_transfer_resized/Molossus/';
%boxes = testmodel([name, '_iter_', num2str(ci)],model,test,suffix);
% numparts = numel(pa);

test = getNegativeData(test_path, 'png');
thres = -1;
boxes = cell(1,length(test));
% uwBoxes = cell(1,length(test));
for i = 1:length(test)
    im = imread(test(i).im);
    box = detect_fast(im,model,thres);
    box = nms(box,0.3);

    load([test(i).im(1:end-8) 'vxy.mat']);
    box = box(1,:);
    box = box(:,1:4*numparts);
    xy = reshape(box,size(box,1),4,numparts);
    xy = permute(xy,[1 3 2]);
    xy = squeeze(xy); % x1 y1 x2 y2
%     quant_xy = round(xy); quant_xy(quant_xy == 0) = 1;
    centbox = zeros(2,numparts);
    for bi = 1:numparts
        centbox(1,bi) = (xy(bi,3) + xy(bi,1)) / 2;
        centbox(2,bi) = (xy(bi,4) + xy(bi,2)) / 2;
    end
    quant_xy = round(centbox); quant_xy(centbox == 0) = 1;
    
    for bi = 1:numparts
        centbox(1,bi) = centbox(1,bi) + vx(quant_xy(2,bi), quant_xy(1,bi));
        centbox(2,bi) = centbox(2,bi) + vy(quant_xy(2,bi), quant_xy(1,bi));
    end
    centbox = centbox';

    name = [test(i).im(1:end-8) 'parts'];
    dlmwrite([name '.txt'], centbox);

%     % TODO: bbox unwarping
%     for bi = 1:numparts
%         xy(bi,1) = xy(bi,1) - vx(quant_xy(bi,2), quant_xy(bi,1));
%         xy(bi,2) = xy(bi,2) - vy(quant_xy(bi,2), quant_xy(bi,1));
%         xy(bi,3) = xy(bi,3) - vx(quant_xy(bi,4), quant_xy(bi,3));
%         xy(bi,4) = xy(bi,4) - vy(quant_xy(bi,4), quant_xy(bi,3));
%     end
%     uwbox = reshape(xy',[1,4*numparts]);

    if display
        src_im = imread([src_path test(i).im(end-21:end-9) '.png']);

        subplot(1,2,1);
        showboxes(im,box(1,:),colorset);
        subplot(1,2,2);
    %     showboxes(src_im,uwbox,colorset);
        imagesc(src_im); axis image; axis off;
        for bi = 1:numparts
            hold on
            plot(centbox(bi,1),centbox(bi,2),'g*');
            plot((xy(bi,3) + xy(bi,1)) / 2, (xy(bi,4) + xy(bi,2)) / 2, 'b.');
        end
        hold off
        pause;
    end

    boxes{i} = box;
%     uwBoxes{i} = uwbox;
end
