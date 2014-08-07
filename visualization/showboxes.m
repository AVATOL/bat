%function showboxes(im, boxes, partcolor, omit, isSave, imName)
function showboxes(im, boxes, partcolor, omit, linst)

if nargin < 3
	%partcolor = {'g','g','y','r','r','y','m','m','y','b','b','y','c','c'};
    partcolor = {'g','r','r','r','r','r','b','b','b','b','b'};
    %isSave = 0;
    %imName = 'picture.png';
    numparts = length(partcolor);
    omit = zeros(1,numparts);
    linst = '-';
end

numparts = length(partcolor);

if nargin < 5
    linst = '-';
end
if nargin < 4
    omit = zeros(1,numparts);
    linst = '-';
end

if length(omit) ~= numparts
  tmp = zeros(1,numparts);
  tmp(omit) = 1;
  omit = tmp;
end

imagesc(im); axis image; axis off;
if ~isempty(boxes)
  box = boxes(:,1:4*numparts);
  xy = reshape(box,size(box,1),4,numparts);
  xy = permute(xy,[1 3 2]);
	x1 = xy(:,:,1);
	y1 = xy(:,:,2);
	x2 = xy(:,:,3);
	y2 = xy(:,:,4);
	for p = 1:size(xy,2)
    if omit(p)
      continue
    end
		line([x1(:,p) x1(:,p) x2(:,p) x2(:,p) x1(:,p)]',[y1(:,p) y2(:,p) y2(:,p) y1(:,p) y1(:,p)]',...
		'color',partcolor{p},'linewidth',2,'LineStyle',linst);
        hold on
        plot(x1(:,p)/2+x2(:,p)/2, y1(:,p)/2+y2(:,p)/2,'.','MarkerSize',15,'color',partcolor{p});
	end
end
% JFrame = get(handle(gcf),'JavaFrame');
% JFrame.setMaximized(true);
% drawnow;
% if isSave == 1
%     saveas(gcf,['./GT/GT_',imName]);
% end

