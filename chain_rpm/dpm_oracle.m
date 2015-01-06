function label = dpm_oracle(params, model, xi, yi)
% INPUT: 
% params = {overlap, thresh} 
% model : model(1).node(i).{w,i}, model(1).edge(i,j).{w,i} for ch->pa
% xi = {pyra}
% yi = {bbox}
% OUTPUT:
% label = {bbox, fmaps, level}

latent = false;
if nargin > 3 && ~isempty(yi.bbox)
    latent = true; % do loss augmentation
    bbox = yi.bbox;
end
nV = params.num_parts;
overlap = params.overlap;
pyra = xi.pyra;
levels = 1:length(pyra.feat);
boxes = zeros(length(levels),nV*4+2);
boxes(:,end) = -inf;
fmaps = cell(1,length(levels)); % feature_maps

%% parse model
model = wtomodel(model.w, model); % update model.filter to do Inference
[nodes,edges,filters,resp] = parse_model(model,pyra);
assert(nV == size(nodes,1));

%% main loops
for lvl = levels
    % 0) skip if any bbox overlaps with gt's not more than 0.5
    if latent
        skipflag = 0;
        for k = 1:nV
            sizx = nodes(k).sizx; sizy = nodes(k).sizy;
            ovmask = testoverlap(sizx,sizy,pyra,lvl,bbox(k,:),overlap);
            if ~any(ovmask)
                skipflag = 1;
                break;
            end
        end
        if skipflag == 1 
            continue;
        end
    end 
    
    % 1) unary potentials with loss augmentation
    resp{lvl} = fconv(pyra.feat{lvl},filters,1,length(filters)); % return 1xnV 

    for k = 1:nV
        nodes(k).unary = resp{lvl}{k} + nodes(k).bias;
        nodes(k).collect = zeros(size(nodes(k).unary));

        % loss augment: add 1/nV to unary(overlap<threshod)
        if latent 
            sizx = nodes(k).sizx; sizy = nodes(k).sizy;
            ovmask = testoverlap(sizx,sizy,pyra,lvl,bbox(k,:),overlap);
            ovmask = ~ovmask;
            nodes(k).unary(ovmask) = nodes(k).unary(ovmask) + 1/nV;
        end       
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
        
        % DEBUG code
        if params.show_interm
            figure(1005); imagesc(nodes(k).collect);
            title(sprintf('nodes(%d).collect', k));
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
    [bb,fmaps{lvl}] = backtrack(rx,ry,lvl,nodes,edges,pyra,parent,latent);
    boxes(lvl,:) = [bb lvl score];
end % lvl

if all(boxes(:) == 0)
    error('!!! boxes in all levels are empty !!!\n');
end

%% outputs
[~,ii] = max(boxes(:,end)); 
label.bbox = boxes(ii,:);
if latent  
  label.level = ii;
  label.fmap = fmaps{ii};
end


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
