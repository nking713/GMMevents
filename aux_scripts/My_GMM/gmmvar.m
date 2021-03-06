function [gmm,FrEn,U] = gmmvar (data,K,options);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   [gmm,FrEn] = gmmvar (data,K,options)
%
%   Computes the Aposteriori pdfs of a mixture model using the variational
%   Bayesian learning approach for a given number of classes, K. K may
%   be a vector - a model will be fitted for each element of
%   K. Convergence is assumed after loopmax (default 100) iterations. 
%   
%   Function returns the mixture components' mean and co-variance
%   matrices in mue and sigma, as well as the class  posterior
%   membership probability in pjgx. FrEn is the  estimated free energy
%   for each model 
%
%   The structure data consists of 
%       data           the actual data for clustering 
%
%
%  options may be set to contain:
%     options.cyc :=  max. number of iterations (default=50)
%     options.tol :=  minimum improvement of free energy
%                     function (default=1e-5%)
%     options.init := initial fitting: 
%             conditional : full conditioanl (default) 
%             rand        : random posteriors
%             kmeans      : k-means init
%     options.cov := shape of covariance matrix: 
%                    'diag'=diagonal ; 'full'=full cov. mat. default)
%
%  options.plot    :=  graphical display : 1=yes 0=no (default)
%  options.display :=  display intermeidate free energy values: 
%                      1=yes 0=no (dafault)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

default.cyc=100;
default.tol=1e-5;
default.init='rand';
default.plot=0;
default.cov='diag';
default.display=0;
default.testcovmat=1;


oldFrEn=1;
MIN_COV=eps;

if (nargin<1) 
  disp('Usage: gmm=gmmvar(data,K,options);');
  return;
end;

if nargin<2
  error('Missing Parameter for Number of Kernels ');
end;

N=size(data,1);
ndim=size(data,2);
if (N<ndim),
  data=data';
  [N,ndim]=size(data);
end;

if ((nargin<3) | isempty(options))
  options=default;
else
  if ~isfield(options,'cyc'),
    options.cyc=default.cyc;
  end;

  if ~isfield(options,'tol')
    options.tol=default.tol;
  end;
  
  if isfield(options,'cov')
    if ~ismember(options.cov,['diag','full','spherical'])
      error('Unknown covariance matrix shape option');
    end;
  else
    options.cov=default.cov;
  end;

  if isfield(options,'init')
    if ~ismember(options.init,['conditional','rand','kmeans'])
      error('Unknown intialisation option');
    elseif strcmp(options.init,'kmeans'),
      if any(K==1),
	disp('Changing intialisation to default');
	options.init='conditional';
      elseif any(ndim>K)
	disp(sprintf(...
	    'K-means initalisation not recommended %d>%d',ndim,K));
      end;
    end;
  else
    options.init=default.init;
  end;

  if isfield(options,'plot')
    if ~ismember(options.plot,[0 1 2])
      error('Unknown plotting flag');
    end;
  else
    options.plot=default.plot;
  end;

  if isfield(options,'testcovmat')
    if ~ismember(options.testcovmat,[0 1])
      error('Unknown Covariance Matrix Test flag');
    end;
  else
    options.testcovmat=default.testcovmat;
  end;
  
  if isfield(options,'display')
    if ~ismember(options.display,[0 1])
      error('Unknown display flag');
    end;
  else
    options.display=default.display;
  end;
end; % if nargin

if ndim~=2,
  options.plot=0;			% no plotting but for ndim==2;
end;


A=length(K);
FrEn=zeros(1,A);
U=nan*zeros(options.cyc,A,20);

% initialise
for a=1:A,
  gmm(a)=gmmvarinit(data,K(a),options);
  % save for resetting during convergence problems
  gmminit(a).post=gmm(a).post;
end;

if options.plot
  % grid for plotting contours
  dmin=min(data);
  dmax=max(data);
  dspace=range(data)./30;
  [Xgrid,Ygrid] = meshgrid(dmin(1):dspace(1):dmax(1),dmin(2): ...
			   dspace(2):dmax(2));
  [nXgrid,nYgrid]=size(Xgrid);
  colstr={'y.';'m.';'c.';'r.';'g.';'b.';'k.'};
  Ncols=length(colstr);
  cpf=(options.plot==2);
  plotoptions{1}=nXgrid;
  plotoptions{2}=nYgrid;
  plotoptions{3}=Xgrid;
  plotoptions{4}=Ygrid;
  plotoptions{5}=Ncols;
  plotoptions{6}=colstr;
  plotoptions{7}=cpf;
  figure;
end;
S=[];
for a=1:A,				% iterating over q-mixture components

  for cyc=1:options.cyc,
    
    % The E-Step, i.e. estimating Q(hidden variables)
    gmm(a).pjgx=estep(gmm(a),data,N,ndim,K(a));

    % The M-Step, i.e. estimating Q(model parameters)
    gmm(a)=mstep(gmm(a),data,N,ndim,K(a));
    
    % computation of free energy 
    [FrEn(a),U(cyc,a,1:3)]=freeener(gmm(a),data,N,ndim,K(a));
   
    % check change of Free Energy
    if abs((FrEn(a) - oldFrEn)/oldFrEn*100) < options.tol, 
     break; 
    else
      oldFrEn=FrEn(a);
    end;

    if options.display, 
      disp(sprintf('Iteration %d ; Free-Energy = %f',cyc,FrEn(a))); 
    end;
    
    %%%%%%%%% optional drawing for demos
    if options.plot
      contplot(gmm(a),data,K(a),plotoptions);
    end;
 
  end;					% for i=1:options.cyc,
  
  disp(sprintf('Model %d: %d kernels, %d dimensions, %d data samples',...
	       a,K(a),ndim,N));
  disp(sprintf('Final Free-Energy (after %d iterations)  = %f',...
	       cyc,FrEn(a))); 
 
end;				% for a=1:A,

for a=1:A,
  gmm(a).pa=1./sum(exp(-FrEn+FrEn(a)));
end;
[pFrEn{1:A}]=deal(gmm.pa);
pFrEn=cat(2,pFrEn{:});
FrEn=[FrEn;pFrEn];

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%  E-STEP  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [pjgx]=estep(gmm,data,N,ndim,K);

[Dir_alpha{1:K}]=deal(gmm.post.Dir_alpha);
Dir_alpha=cat(2,Dir_alpha{:});
PsiDiralphasum=digamma(sum(Dir_alpha));

for k=1:K,
  qp=gmm.post(k);	% for ease of referencing
  
  ldetWishB=0.5*log(det(qp.Wish_B));
  PsiDiralpha=digamma(qp.Dir_alpha);
  PsiWish_alphasum=0;
  for d=1:ndim,
    PsiWish_alphasum=PsiWish_alphasum+...
	digamma(qp.Wish_alpha+0.5-d/2);
  end;
  PsiWish_alphasum=PsiWish_alphasum*0.5;
  
  dist=mdist(data,qp.Norm_Mu,qp.Wish_iB*qp.Wish_alpha);
  
  NormWishtrace=0.5*trace(qp.Wish_alpha*qp.Wish_iB*qp.Norm_Cov);
  
  gmm.pjgx(:,k)=exp(PsiDiralpha-PsiDiralphasum+PsiWish_alphasum-ldetWishB+ ...
      dist-NormWishtrace-ndim/2*log(2*pi));

  %gmm.pjgx(:,k)=gaussmd(data,qp.Norm_Mu,inv(qp.Wish_iB*qp.Wish_alpha));
  %gmm.pjgx(:,k)=gmm.pjgx(:,k)*qp.Dir_alpha/N;
  
end;


% normalise posteriors of hidden variables.
gmm.pjgx=gmm.pjgx; % +eps;
col_sum=sum(gmm.pjgx,2);
gmm.pjgx=gmm.pjgx./(col_sum*ones(1,K));
pjgx=gmm.pjgx;
% another way of normalising
%    for k=1:K(a),
%      col_sum=gmm(a).pjgx(:,k)*ones(1,K(a));
%      inv_prob=sum(gmm(a).pjgx./col_sum,2);
%      if any(inv_prob==0)
% 	disp(['Zero normalisation constant for hidden variable' ...
% 	      ' posteriors']);
% 	return;
%      else
% 	gmm(a).pjgx(:,k)=1./sum(gmm(a).pjgx./col_sum,2);
%      end;
%    end ;

return;					% estep
 
%%%%%%%%%%%%%%%%%%%%%%%%%%  M-STEP  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [gmm]=mstep(gmm,data,N,ndim,K);

pr=gmm.priors;			% model priors

gammasum=sum(gmm.pjgx,1);

for k = 1:K,
  qp=gmm.post(k);		% temporary structure (q-distrib);
  
  % Update posterior Normals
  postprec=gammasum(k)*qp.Wish_alpha*qp.Wish_iB+pr.Norm_Prec;
  postvar=inv(postprec);
  weidata=data'*gmm.pjgx(:,k); % unnormalised sample mean

  Norm_Mu=postvar*(qp.Wish_alpha*qp.Wish_iB*weidata+ ...
		       pr.Norm_Prec*pr.Norm_Mu);
  Norm_Prec=postprec;
  Norm_Cov=postvar;

  %Update posterior Wisharts
  Wish_alpha=0.5*gammasum(k)+pr.Wish_alpha;
  dist=data-ones(N,1)*Norm_Mu';
  
  sampvar=zeros(ndim);
  % too slow
  %dist=dist';
  % for n=1:N,
  %   sampvar=sampvar+gmm.pjgx(n,k)*(dist(:,n)*dist(:,n)');
  % end;
  for n=1:ndim,
    sampvar(n,:)=sum((gmm.pjgx(:,k).*dist(:,n))*ones(1,ndim).*dist,1);
  end;
  
  Wish_B=0.5*(sampvar+gammasum(k)*Norm_Cov)+pr.Wish_B;
  Wish_iB=inv(Wish_B);
      
  % Update posterior Dirichlet
  Dir_alpha=gammasum(k)+pr.Dir_alpha(k);
  
  gmm.post(k).Norm_Mu=Norm_Mu;
  gmm.post(k).Norm_Prec=Norm_Prec;
  gmm.post(k).Norm_Cov=Norm_Cov;
  gmm.post(k).Wish_alpha=Wish_alpha;
  gmm.post(k).Wish_B=Wish_B;
  gmm.post(k).Wish_iB=Wish_iB;
  gmm.post(k).Dir_alpha=Dir_alpha;
end;

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%  FREE ENERGY  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [FrEn,U]=freeener(gmm,data,N,ndim,K);

KLdiv=0;avLL=0;
pr=gmm.priors;

[Dir_alpha{1:K}]=deal(gmm.post.Dir_alpha);
Dir_alpha=cat(2,Dir_alpha{:});
Dir_alphasum=sum(Dir_alpha);
PsiDir_alphasum=digamma(Dir_alphasum);
ltpi=ndim/2*log(2*pi);
gammasum=sum(gmm.pjgx,1);

% entropy of hidden variables, which are not zero
pjgx=gmm.pjgx(:);
ndx=find(pjgx~=0);
Entr=sum(sum(pjgx(ndx).*log(pjgx(ndx))));

for k=1:K,
  % average log-likelihood
  qp=gmm.post(k);		% for ease of referencing

  PsiDiralpha=digamma(qp.Dir_alpha);
  dist=mdist(data,qp.Norm_Mu,qp.Wish_iB*qp.Wish_alpha);
  NormWishtrace=0.5*trace(qp.Wish_alpha*qp.Wish_iB*qp.Norm_Cov);
  ldetWishB=0.5*log(det(qp.Wish_B));
  PsiWish_alphasum=0;
  for d=1:ndim,
    PsiWish_alphasum=PsiWish_alphasum+...
	digamma(qp.Wish_alpha+0.5-d/2);
  end;
  PsiWish_alphasum=0.5*PsiWish_alphasum;
  
  avLL=avLL+gammasum(k).*(PsiDiralpha-PsiDir_alphasum-ldetWishB+...
			  PsiWish_alphasum-NormWishtrace-ltpi)+...
       sum(gmm.pjgx(:,k).*dist);
  
  % KL divergences of Normals and Wishart
  VarDiv=wishart_kl(qp.Wish_B,pr.Wish_B,qp.Wish_alpha,pr.Wish_alpha);
  MeanDiv=gauss_kl(qp.Norm_Mu,pr.Norm_Mu,qp.Norm_Cov,pr.Norm_Cov);
  KLdiv=KLdiv+VarDiv+MeanDiv;
end;

% KL divergence of Dirichlet
KLdiv=KLdiv+dirichlet_kl(Dir_alpha,pr.Dir_alpha);

FrEn=Entr-avLL+KLdiv;
U=[Entr -avLL +KLdiv];

return;					% freeener

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [dist] = mdist (x,mu,C)
%
%   [dist] =  mdist(x,mu,C)
%
%   computes from x values given mean mu and precision C
%   the distance, actually the quantity
%                           
%        -0.5  (x-mu)' C (x-mu)  

d=size(C,1);
if (size(x,1)~=d)  x=x'; end;
if (size(mu,1)~=d)  mu=mu'; end;

[ndim,N]=size(x);
d=x-mu*ones(1,N);

% too slow
% dist=zeros(N,1);
% for l=1:N,
%   dist(l)=-0.5*d(:,l)'*C*d(:,l);
% end;


%d=x-mu*ones(1,N);
Cd=C*d;
% costs memory
% dist=-0.5*diag(d'*C*d);

% less expensive 
dist=zeros(1,N);
for l=1:ndim,
  dist=dist+d(l,:).*Cd(l,:);
end
dist=-0.5*dist';

return;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function contplot(gmm,data,K,plotoptions)
%
% continous plotting of results
%

[nXgrid,nYgrid,Xgrid,Ygrid,Ncols,colstr,cpf]=deal(plotoptions{:});

clf
[y,classndx]=max(gmm.pjgx,[],2);
for k=1:K,
  plot(data(find(classndx==k),1),data(find(classndx==k),2), ...
       colstr{rem(k,Ncols)+1}),hold on;
  centre=[gmm.post(k).Norm_Mu];
  Cov=gmm.post(k).Wish_B/gmm.post(k).Wish_alpha;
  text(centre(1),centre(2),sprintf('X-%s%d',blanks(k),k));
  if cpf
    for xg=1:nXgrid, 
      for yg=1:nYgrid,
	pdf(xg,yg)=gaussmd([Xgrid(xg,yg) Ygrid(xg,yg)],centre,Cov);
      end;
    end;
    pdf=pdf./(max(max(pdf))-min(min(pdf)));
    contour(Xgrid(1,:),Ygrid(:,1),pdf,[.67 .67],':b');
  end;
end;
drawnow, hold off;
