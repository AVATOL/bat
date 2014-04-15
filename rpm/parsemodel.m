function [components,filters,resp] = parsemodel(model,pyra)
% same as modelcomponents()
% Cache various statistics from the model data structure for later use  
components = cell(length(model.components),1);
for c = 1:length(model.components)
  nmix = length(model.components{c}(1).filterid); % Note pressume nmix are the same 
	for k = 1:length(model.components{c})
		p = model.components{c}(k); % part k at component c
		[p.sizy,p.sizx,p.w,p.biasI,p.filterI,p.defI,p.starty,p.startx,p.step,p.level,p.Ix,p.Iy] = deal([]);
		[p.scale,p.level,p.Ix,p.Iy] = deal(0);
    [p.on,p.om,p.onI,p.omI] = deal([]);

		% store the scale of each part relative to the component root
		par = p.parent;   
		assert(all(par < k));
    npar = length(par);
    assert(npar > 0);
    
    % bias
% ****assert(all(size(p.biasid) == [nmix nmix npar])); 
		p.b = [model.bias(p.biasid).w]; % here get a vector
		p.b = reshape(p.b,[nmix nmix npar]); % [nmix_ch nmix_pa npar]
		p.biasI = [model.bias(p.biasid).i];
		p.biasI = reshape(p.biasI,[nmix nmix npar]);
		
    % filter [f1 ... fk]
    assert(nmix == length(p.filterid));
    for f = 1:nmix
			x = model.filters(p.filterid(f));
			[p.sizy(f) p.sizx(f) foo] = size(x.w);
			p.filterI(f) = x.i;
    end
    
    % omission o_v
    assert(nmix == length(p.onid));
    assert(all(p.onid == p.filterid)); % may relax
    p.on = [ model.ominode(p.onid).w ];
    p.on = reshape(p.on, [1 nmix]);
		p.onI = [ model.ominode(p.onid).i ];
		p.onI = reshape(p.onI, [1 nmix]);
		
    if k > 1 % non-root
      % def
      assert(all([nmix npar] == size(p.defid)));
      for n = 1:npar	  
        for m = 1:nmix
          %f = nmix*(n-1) + m;
          x = model.defs(p.defid(m,n));
          p.w(:,m,n)  = x.w';
          p.defI(m,n) = x.i;
          ax = x.anchor(1);
          ay = x.anchor(2);    
          ds = x.anchor(3);
          p.scale = ds + components{c}(par).scale;
          % amount of (virtual) padding to hallucinate
          step = 2^ds;
          virtpady = (step-1)*pyra.pady;
          virtpadx = (step-1)*pyra.padx;
          % starting points (simulates additional padding at finer scales)
          p.starty(m,n) = ay-virtpady;
          p.startx(m,n) = ax-virtpadx;      
          p.step   = step;
        end
      end

      % omission o_vu
      assert(all([nmix npar] == size(p.omid)));
      assert(all(all(p.omid == p.defid))); % may relax
      p.om = [ model.omiedge(p.omid).w ];
      p.om = reshape(p.om, [nmix npar]);
      p.omI = [model.omiedge(p.omid).i];
      p.omI = reshape(p.omI, [nmix npar]);
    end % k > 1

    p.id = k;
		components{c}(k) = p;
	end
end

% filters and resp
if ~isstruct(pyra)
  resp = cell(1,1);
  filters = cell(1,1);
  filters{1} = model.filters(1).w;
  return
end
  
resp    = cell(length(pyra.feat),1);
filters = cell(length(model.filters),1);
for i = 1:length(filters)
	filters{i} = model.filters(i).w;
end
