function DOS_Tr
%% DOS calculation using tetrahedron method
% The program is for DOS calculation using tetrahedron method, referring
% to articles " G Lehmann and M Taut. On the numerical calculation
% of the density of states and related properties. physica
% status solidi (b), 54(2):469{477, 1972" and "Peter E Bl��ochl, Ove Jepsen,
% and Ole Krogh Andersen. Improved tetrahedron method for brillouin-zone 
% integrations. Physical Review B, 49(23):16223, 1994".

% The first edition is finished in Nov. 9, 2017.

%% Important notice for initial parameters!!!
% Necessary parameters: 
% 0. two files including band freqeuncies between the high symmetry points 
% band frequencies with k-points coordinates in the whole Brillouin zone
% (Notice: The band data could also be the half of 
% the Brillouin zone in latter two files if there is time-reversal symmetry, which will save half of
% the computing time for bands. The values of DOS only need to be multiplied 
% by 2 if you choose to use half of the Brillouin zone.);
% 1. the range of kx, ky, kz; 2. the number of k points; 3. number of
% bands; 4. the reciprocal vectors.
% Optional parameters: 4. maximum and minimum of band frequency (w_max, w_min); 
% 5. resolution about the frequency  (N_w); 6. parameters about plot like color, fontsize, etc.

draw_band=1;    % draw the band structure with DOS
% draw_band=0;    % only calculate DOS and output the DOS data

file_bandline='band.txt';
file_bandmap='frequency_tetrahedron.txt';

file_DOSdata='output.txt';  % save file for Density of states data

% reciprocal vectors are only used to optimize the interpolation
reciprocalvector1=[0 1 1];
reciprocalvector2=[1 0 1];
reciprocalvector3=[1 1 0];

% volumn of BZ is a parrallelepiped with range ki in [-b_len(i)/2, b_len(i)/2], b_len(i) is the
% reciprocal lattice length in i-th dimension (i=1,2,3).
% if you use half of the BZ as k3 range in [0, b_len(3)], then b_len(3)=1/2
b_len=[1, 1, 1];
frac_BZ=1;  % if you use half of BZ, then set it to 1/2
% num_kpoints(i) is the number of k points along the bi axis, 
num_kpoints=[12,12,12]; 

N_band=10;       % the total number of frequency bands

w_max_custom=-1;   % the range of frequency, '-1' denotes default settings
w_min_custom=-1;

N_w=20000;       % denotes the resolution of frequency : dw = (w_max - w_min) / N_w

kinter = 30;       % the inter quantity of k points between two high symmetry points
maxDOS_custom=-1;        % the parameters about plot, '-1' denotes default settings
fs_custom=10;           
bandcolor_custom='b';
bottomcolor_custom='k';
thelinewidth_custom=1;

%% Initialization and import data
% k_step(i) is the interval length along i-th dimension
k_step=b_len./(num_kpoints-1);

% n_kpoints is the total number of k points
% N_kpoints is the product of number of bands and total number of k points in Brillouin zone
n_kpoints=prod(num_kpoints);
v_tetra=1/6/n_kpoints;
% import data
% the two importing txt files are arranged as matrix of N*1 and N*3
dataall=importdata(file_bandmap);
datak=dataall(:,1:3);   % beginning three columns are k-points coordinates
k_min=min(datak(:,1:3));
dataw=dataall(:,4:end); % the other columns are the bands number
datakn=round((datak-k_min)./k_step)+1;  % integer index of k points, starting from 1


if w_max_custom==-1
    w_max=1.05*max(dataw(:)); % the maximum of frequency should be larger than max(dataw) a little
else
    w_max=w_max_custom;
end

if w_min_custom==-1
    w_min=0;
else
    w_min=w_min_custom;
end

% other parmeters

step_w=(w_max-w_min)/N_w;      % the resolution of frequency
DOSarrary=zeros(N_w+1,1);       % initialze the density of states array

% initializing w_grid to store the frequency of all the k points
w_grid(num_kpoints(1),num_kpoints(2),num_kpoints(3),N_band)=0;
for n_k = 1:n_kpoints
    for n_band = 1:N_band
        w_grid(datakn(n_k,1),datakn(n_k,2),datakn(n_k,3),n_band)=dataw(n_k,n_band);
    end
end

% optimize the grid according to "Peter E Bl��ochl, Ove Jepsen,
% and Ole Krogh Andersen. Improved tetrahedron method for brillouin-zone 
% integrations. Physical Review B, 49(23):16223, 1994".
diagnal_len0=norm(reciprocalvector1+reciprocalvector2+reciprocalvector3);
diagnal_len1=norm(-reciprocalvector1+reciprocalvector2+reciprocalvector3);
diagnal_len2=norm(reciprocalvector1-reciprocalvector2+reciprocalvector3);
diagnal_len3=norm(reciprocalvector1+reciprocalvector2-reciprocalvector3);
diagnal_min=min([diagnal_len0,diagnal_len1,diagnal_len2,diagnal_len3]);
if diagnal_len0==diagnal_min
    w_grid_opt=w_grid;
elseif diagnal_len1==diagnal_min
    w_grid_opt=flip(w_grid,1);
elseif diagnal_len2==diagnal_min
    w_grid_opt=flip(w_grid,2);
elseif diagnal_len2==diagnal_min
    w_grid_opt=flip(w_grid,3);
else
    fprintf('error!\n');
    exit(1);
end

%% Check the input information

if size(datak,1)~=n_kpoints
    error('Error! The number of k points is wrong.\n');
elseif size(dataw,2)~=n_band
    error('Error! The number of bands is wrong.\n');
end

%% DOS calculation
% the parallelepiped is divided across 3-6 diagonal, according to "Peter E Blochl, Ove Jepsen,
% and Ole Krogh Andersen. Improved tetrahedron method for brillouin-zone 
% integrations. Physical Review B, 49(23):16223, 1994". The DOS contribution of
% one tetrahedron is illustrated in its Appendix C.
parallelepiped(8)=0; % initializing parallelepiped
tetra(6,4)=0;   % initializing tetrahedron, storing the corner frequencies of tetrahedra
for nk1=1:num_kpoints(1)-1
    for nk2=1:num_kpoints(2)-1
        for nk3=1:num_kpoints(3)-1
            for n_band=1:N_band
                parallelepiped(1)=w_grid_opt(nk1+1,nk2,nk3,n_band);
                parallelepiped(2)=w_grid_opt(nk1+1,nk2+1,nk3,n_band);
                parallelepiped(3)=w_grid_opt(nk1,nk2,nk3,n_band);
                parallelepiped(4)=w_grid_opt(nk1,nk2+1,nk3,n_band);
                parallelepiped(5)=w_grid_opt(nk1+1,nk2,nk3+1,n_band);
                parallelepiped(6)=w_grid_opt(nk1+1,nk2+1,nk3+1,n_band);
                parallelepiped(7)=w_grid_opt(nk1,nk2,nk3+1,n_band);
                parallelepiped(8)=w_grid_opt(nk1,nk2+1,nk3+1,n_band);
                tetra(:,[1 4])=ones(6,1)*[parallelepiped(3),parallelepiped(6)];
                tetra(1,[2 3])=[parallelepiped(1),parallelepiped(2)];
                tetra(2,[2 3])=[parallelepiped(2),parallelepiped(4)];
                tetra(3,[2 3])=[parallelepiped(4),parallelepiped(8)];
                tetra(4,[2 3])=[parallelepiped(7),parallelepiped(8)];
                tetra(5,[2 3])=[parallelepiped(5),parallelepiped(7)];
                tetra(6,[2 3])=[parallelepiped(1),parallelepiped(5)];
                for n_tetra=1:6
                    w_corner=sort(tetra(n_tetra,:));
                    w21=w_corner(2)-w_corner(1);
                    w31=w_corner(3)-w_corner(1);
                    w41=w_corner(4)-w_corner(1);
                    w32=w_corner(3)-w_corner(2);
                    w42=w_corner(4)-w_corner(2);
                    w43=w_corner(4)-w_corner(3);
                    nw_min=ceil((w_corner(1)-w_min)/step_w);
                    nw_max=floor((w_corner(4)-w_min)/step_w);
                    for nw=nw_min:nw_max
                        w_tmpt=step_w*nw+w_min;
                        if w41 == 0
                            dos_tmpt=v_tetra/step_w;
                            DOSarrary(nw+1)=DOSarrary(nw+1)+dos_tmpt;
                            break;
                        elseif w_tmpt < w_corner(1)
                            continue;
                        elseif w_tmpt <= w_corner(2)
                            if w21 > 0
                                dos_tmpt=3*v_tetra*(w_tmpt-w_corner(1))^2/w21/w31/w41;
                            else
                                if w31 > 0
                                    dos_tmpt=0;
                                else
                                    dos_tmpt=3*v_tetra/w41;
                                end
                            end
                        elseif w_tmpt <= w_corner(3)
                            dos_tmpt=3*v_tetra/w31/w41*(w21+2*(w_tmpt-w_corner(2))-...
                                (w31+w42)*(w_tmpt-w_corner(2))^2/w32/w42);
                        elseif w_tmpt <= w_corner(4)
                            dos_tmpt=3*v_tetra*(w_tmpt-w_corner(4))^2/w43/w42/w41;
                        else
                            continue;
                        end
                    if dos_tmpt > v_tetra/step_w      
                        dos_tmpt=v_tetra/step_w;    % the maximum of DOS contribution for one tetrahedron               
                    end
                    DOSarrary(nw+1)=DOSarrary(nw+1)+dos_tmpt;
                    end
                end
            end
        end
    end
end

% output DOS data into output.txt
file_output=fopen(file_DOSdata,'wt');
for nprint_w=1:N_w+1
    fprintf(file_output,'%.10f %.10f\n',w_min+step_w*(nprint_w-1),DOSarrary(nprint_w)/frac_BZ);
end

%% Band plot and DOS
% import band data
if draw_band==0
    return;
end

data_band = dlmread(file_bandline,' ',0,0); % the format corresponds to bash file

nbands = size(data_band,2)-3;

if nbands~=N_band       % numbers of band in two file are unequal!
    exit('error:numbers of band in two file are unequal!');
end

kindex = 1:size(data_band(:,1),1);
Ks = 0;   % record all
kidx=[];    % record the nodes of band plot

%scale each BZ section with the tight proportion
b1=reciprocalvector1;
b2=reciprocalvector2;
b3=reciprocalvector3;
bs = [b1;b2;b3];
imax = (length(kindex)-1)/(kinter+1); % how many sections
for i=1:imax
    k1=(i-1)*(kinter+1)+1; %starting section k
    k2=k1+(kinter+1); %ending section k
    A=kindex(k1:k2);
    
    % compute the length of a section (rr)
    coor_k1=data_band(k1,1:3)*bs;
    coor_k2=data_band(k2,1:3)*bs;
    r1=norm(coor_k1);
    r2=norm(coor_k2);
    if r1*r2==0
        rr=abs(r1-r2);
    else
        cost=sum(coor_k1.*coor_k2)/r1/r2;
        if r1^2+r2^2-2*r1*r2*cost<0
            error('Error:|r|<0\n');
        end
        rr=sqrt(r1^2+r2^2-2*r1*r2*cost);
    end
    
    A1=Ks(end) + (A-k1)*rr/(k2-k1);
    Ks(k1:k2) = A1;
    kidx = [kidx,k1];
end
kidx=[kidx,k2];

fs=fs_custom;
bandcolor=bandcolor_custom;
bottomcolor=bottomcolor_custom;
thelinewidth=thelinewidth_custom;
figure
for i = 1:nbands 
    plot(Ks,data_band(:,3+i),'-','color',bandcolor,'LineWidth',thelinewidth);
    hold on;
end

if maxDOS_custom==-1
    maxDOS=ceil(max(DOSarrary));
else
    maxDOS=maxDOS_custom;
end

DOSarrary(DOSarrary>maxDOS)=maxDOS;
w_var=w_min+step_w*((1:(N_w+1))-1);   % frequency -- the variable of DOS
DOS_nrm=(Ks(end)-Ks(1))*DOSarrary/maxDOS+Ks(end);
plot(DOS_nrm,w_var,'Color',bandcolor);
fill(DOS_nrm,w_var,bandcolor);
plot(DOS_nrm(1)*ones(size(w_var,2),1),w_var,'color',bottomcolor);
set(gca,'FontSize',fs,'FontName','Helvetica','Layer','top');
set(gca,'xTick', [Ks(kidx),Ks(end)*2],'XTickLabel',{'H','\Gamma','N','P','\Gamma (0)',...
    num2str(maxDOS)},'XGrid','on','GridLineStyle','-','layer','bottom');
xlim([Ks(1),2*Ks(end)]);
ylim([w_min,w_max]);
ylabel('Normalized frequency \omega (a/\lambda_0)');
title('Band structure and its corresponding DOS');
hold off

saveas(gcf,'BandFigure.fig');
print('-depsc','-painters','BandFigure');