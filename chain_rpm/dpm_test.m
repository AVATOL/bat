function boxes = dpm_test(params, model, im, overlap)
% 

if nargin < 4
    overlap = 0.3;
end

if ischar(im)
    im = imread(im);
end
pyra = hog_pyra(im, params);

nV = model.num_parts;
levels = 1:length(pyra.feat);
boxes = zeros(length(levels),nV*4+2);

%% parse model
model = wtomodel(model.w, model); % update model.filter to do Inference
[nodes,edges,filters,resp] = parse_model(model,pyra);
assert(nV == size(nodes,1));

%% main loops
for lvl = levels   
    % 1) unary potentials with loss augmentation
    resp{lvl} = fconv(pyra.feat{lvl},filters,1,length(filters)); % return 1xnV 

    for k = 1:nV
        nodes(k).unary = resp{lvl}{k} + nodes(k).bias;
        nodes(k).collect = zeros(size(nodes(k).unary)); 
    end % nV
    
    % 2) pass messages from leaves to root
    parent = model.parent;
    for k = nV:-1:1 % assume topological order: parent(k) < k
        par = parent(k); 
        if par == 0 % 1's par is 0, a virtual root
            ktop = [];
            [nodes(k).msg,nodes(k).Ix,nodes(k).Iy] = deal(0);
        else
            ktop = edges(k,par);
            [nodes(k).msg,nodes(k).Ix,nodes(k).Iy] = ...
                deal(zeros(size(nodes(par).collect)));
        end
        
        % collect msgs from ch: collect_k(y_k) = sum_l msg_lk(y_k)
        ch_k = find(parent == k);
        for ci = ch_k
            nodes(k).collect = nodes(k).collect + nodes(ci).msg;
        end

        % compute nodes(k).msg to par and keep backpointers
        nodes(k) = compute_msg(nodes(k),ktop);
    end % nV

    % 3) final collection for 0
    ch_0 = find(parent == 0);
    score = nodes(ch_0).msg;
    ry = nodes(ch_0).Iy;
    rx = nodes(ch_0).Ix;

    % 4) backtracking
    bb = backtrack(rx,ry,lvl,nodes,edges,pyra,parent,0);
    boxes(lvl,:) = [bb lvl score];
end % lvl

if all(boxes(:) == 0)
    error('!!! boxes in all levels are empty !!!\n');
end

%% post-processing
boxes = nms(boxes, overlap);
[~,sI] = sort(boxes(:,end),'descend');
boxes = boxes(sI,:);


%% helper functions
function child = compute_msg(child,edge,eta)
% compute msg from child to parent 
% m_ki(y_i) = max_{y_k} [ collect(y_k) + eta*unary(y_k) + pairwise(y_k,y_i) ]
% ADD fields msg Iy Ix to child

if nargin < 3
    eta = 1;
end

% add unary
child.collect = child.collect + eta*child.unary;

if isempty(edge) % msg to 0
    % max without pairwise, msg becomes a number
    [msg,Iloc] = max(child.collect(:));
    [Iy,Ix] = ind2sub(size(child.collect), Iloc);
else
    defw = edge.w;
    startx = edge.startx;
    starty = edge.starty;
    step = edge.step;
    
    if defw(1) == 0
        defw(1) = defw(1) + 1e-5;
    end
    if defw(3) == 0
        defw(3) = defw(3) + 1e-5;
    end
    
    % distance transform for pairwise potential
    [Ny,Nx] = size(child.msg);
    [Ix,Iy,msg] = deal(zeros([Ny,Nx]));
    [msg,Ix,Iy] = shiftdt(child.collect,...
        defw(1),defw(2),defw(3),defw(4),...
        startx,starty,Nx,Ny,step);
end

child.msg = msg;
child.Ix  = Ix;
child.Iy  = Iy;


function [bb,fmap] = backtrack(rx,ry,lvl,nodes,edges,pyra,parent,write)
% backtracking from root to leaves

nV = length(nodes);
padx = pyra.padx; 
pady = pyra.pady; 
scale = pyra.scale(lvl);
bb = zeros(nV,4);
ptr = zeros(nV,2);
fmap.blocks = [];

for k = 1:nV
    par = parent(k);
    if par == 0
        x = rx;
        y = ry;
        ptr(k,:) = [x y];
    else
	    x = ptr(par,1);
	    y = ptr(par,2);
	    ptr(k,1) = nodes(k).Ix(y,x);
	    ptr(k,2) = nodes(k).Iy(y,x);
    end

    sizx = nodes(k).sizx; sizy = nodes(k).sizy;
    x1  = (ptr(k,1)-1-padx)*scale + 1;
    y1  = (ptr(k,2)-1-pady)*scale + 1;
    x2  = x1 + sizx*scale - 1;
    y2  = y1 + sizy*scale - 1;
    bb(k,:) = [x1 y1 x2 y2];

	if write
        % bias
		fmap.blocks(end+1).i = nodes(k).biasI;
		fmap.blocks(end).x   = 1;

        % hog
		x   = ptr(k,1);
		y   = ptr(k,2);
		hog = pyra.feat{lvl}(y:y+sizy-1, x:x+sizx-1, :);
		fmap.blocks(end+1).i = nodes(k).i;
		fmap.blocks(end).x = hog;

        % def
        if par
            px = ptr(par,1);
            py = ptr(par,2);
		    fmap.blocks(end+1).i = edges(k,par).i;
		    fmap.blocks(end).x   = def_feat(px,py,x,y,pady,padx,edges(k,par));
        end
	end
end

bb = reshape(bb',1,4*nV);


function [top,pick] = nms(boxes,overlap,numpart)
% Non-maximum suppression.
% Greedily select high-scoring detections and skip detections
% that are significantly covered by a previously selected detection.

if nargin < 2
    overlap = 0.5;
end
if nargin < 3
    numpart = floor(size(boxes,2)/4);
end

top = [];
if isempty(boxes)
    return;
end

% throw away boxes if the number of candidates are too many
if size(boxes,1) > 1000
    [foo,I] = sort(boxes(:,end),'descend');
    boxes = boxes(I(1:1000),:);
end

% collect bounding boxes and scores  
x1 = zeros(size(boxes,1),numpart);
y1 = zeros(size(boxes,1),numpart);
x2 = zeros(size(boxes,1),numpart);
y2 = zeros(size(boxes,1),numpart);
area = zeros(size(boxes,1),numpart);
for p = 1:numpart
    x1(:,p) = boxes(:,1+(p-1)*4);
    y1(:,p) = boxes(:,2+(p-1)*4);
    x2(:,p) = boxes(:,3+(p-1)*4);
    y2(:,p) = boxes(:,4+(p-1)*4);
    area(:,p) = (x2(:,p)-x1(:,p)+1) .* (y2(:,p)-y1(:,p)+1);
end
% compute the biggest boxes covering detection
rx1 = min(x1,[],2);
ry1 = min(y1,[],2);
rx2 = max(x2,[],2);
ry2 = max(y2,[],2);
rarea = (rx2-rx1+1) .* (ry2-ry1+1);
% combine parts and biggest covering boxes
x1 = [x1 rx1];
y1 = [y1 ry1];
x2 = [x2 rx2];
y2 = [y2 ry2];
area = [area rarea];

s = boxes(:,end);
[vals, I] = sort(s);
pick = [];
while ~isempty(I)
    last = length(I);
    i = I(last);
    pick = [pick; i];

    % find interections
    xx1 = bsxfun(@max,x1(i,:), x1(I,:));
    yy1 = bsxfun(@max,y1(i,:), y1(I,:));
    xx2 = bsxfun(@min,x2(i,:), x2(I,:));
    yy2 = bsxfun(@min,y2(i,:), y2(I,:));

    w = xx2-xx1+1; w(w<0) = 0;
    h = yy2-yy1+1; h(h<0) = 0;    
    inter  = w.*h;

    o = inter ./ repmat(area(i,:),size(inter,1),1);
    o = max(o,[],2);
    % discard BBs overlapped > thres with the current highest pick
    I(o > overlap) = [];
end  
top = boxes(pick,:);
