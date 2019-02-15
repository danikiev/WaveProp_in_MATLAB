% Finite-differences in time domain(FDTD) elastic wave propagation in 3D
% isotropic medium surrounded by simple sponge boundaries with exponential
% decay (Cerjan, 1985).
%
% We solve second order wave equation in time domain and displacement
% formulation getting wavefield in terms of displacement vector [ux, uy, uz].
%
% Elastic medium is parametrized by density and two velocities rho, vp
% and vs . We show CFL condition and number of points per wavelength
% prior running loop over time steps.
%
% We initiate source on a sphere with exponential decay.
%
% Conventional FD star-stencils deliver accuracy O(2,2)
% Stencils: [1 -2 1]/dx2 and [1 -1 -1 1]/4dxdz
% --------------------------------------------------------------
% The code is intentionally writen in a single file
% to simplify start up.
%
% The program does not save any files, add such option manually if needed.
% Drawing the wavefield is computationally demanding. Increase
% IT_DISPLAY value to reduce output and accelerate computation.
%
% The goal is to provide a simple example of elastic wave propagation
% in 3D isotropic medium.
%
% --------------------------------------------------------------
% Oleg Ovcharenko and Vladimir Kazei, 2018
%
% oleg.ovcharenko@kaust.edu.sa
% vladimir.kazei@kaust.edu.sa
%
% King Abdullah University of Science and Technology
% Thuwal, Saudi Arabia
% --------------------------------------------------------------

close all;
% Output every ... time steps
IT_DISPLAY = 40;

%% MODEL
% Model dimensions, [m]
nx = 101;
ny = 101;
nz = 101;
dx = 10;
dy = 10;
dz = 10;

% Elastic parameters
vp = 3300.0 * ones(nz,ny,nx);       % velocity of compressional waves, [m/s]
vs = vp / 1.732;                    % velocity of shear waves, [m/s]
rho = 2800.0 * ones(size(vp));      % density, [kg/m3]

% Lame parameters
lam = rho.*(vp.^2 - 2*vs.^2);       % first Lame parameter
mu =  rho.*vs.^2;                   % shear modulus, [N/m2]

%% TIME STEPPING
t_total = 0.20;                       % [sec] recording duration
dt = 0.1 * min(dx,dz)/sqrt(max(vp(:))^2 + 2 * max(vs(:))^2);
nt = round(t_total/dt);             % number of time steps
t = [0:nt]*dt;

%% SOURCE PARAMETERS
f0 = 15.0;                           % dominant frequency of the wavelet
t0 = 1.20 / f0;                     % excitation time
factor = 1e10;                      % amplitude coefficient
angle_force = 90.0;                 % spatial orientation 90 - along x axis

isrc = round(nx/2);                 % source location along OX
jsrc = round(ny/2);                 % source location along OY
ksrc = round(nz/2);                 % source location along OZ

deg2rad = pi / 180.d0;              % convert degrees to radians
a = pi*pi*f0*f0;
dt2rho_src = dt^2/rho(ksrc,jsrc,isrc);
% source_signal = factor * exp(-a*(t-t0).^2);                                % Gaussian
% source_signal =  -factor*2.0*a*(t-t0)*exp(-a*(t-t0)^2);                    % First derivative of a Gaussian:
source_signal = -factor * (1.0 - 2.0*a*(t-t0).^2).*exp(-a*(t-t0).^2);        % Ricker source time function (second derivative of a Gaussian):

force_x = sin(angle_force * deg2rad) * source_signal * dt2rho_src / (dx * dy * dz);
force_y = cos(angle_force * deg2rad) * source_signal * dt2rho_src / (dx * dy * dz);
force_z = sin(angle_force * deg2rad) * source_signal * dt2rho_src / (dx * dy * dz);
% Comment the line below if need 3 component force source
force_z = zeros(size(force_z));

% moment tensor source signature is the same
% use moment tensor instead of force 1, 0 - use force
mt.flag = 1;
mt.xx = 1;
mt.yy = 1;
mt.zz = 1;
mt.xy = 0;
mt.xz = 0;
mt.yz = 0;
mt.factor = factor;
mt.source_signal = source_signal;

%% OTHER
CFL = max(vp(:)) * dt / min(dx,dz);     % Courant number, should be < 1
min_wavelengh = min(vs(vs>0.1))/f0;     % shortest wavelength bounded by velocity in the air

%% DISTRIBUTED SOURCE OVER A SPHERE
% Radius of the spherical source [grid nodes]
szb = ceil(nx/(10 * 2));
% Create a 3d array with the ones shaping a sphere
SPb = strel('sphere',szb); sphere_b = double(SPb.Neighborhood);
% Uncomment the following 3 lines to make an empty sphere
% szs = szb - 3; dsz = szb - szs;
% SPs = strel('sphere',szs); sphere_s = double(SPs.Neighborhood);
% sphere_s  = padarray(sphere_s,[dsz dsz dsz]);
sphere_s = zeros(size(sphere_b));
sphere_e = sphere_b - sphere_s;

% Add zero padding so the source is of model size
sphere_e = padarray(sphere_e,[nz-ksrc-szb ny-jsrc-szb nx-isrc-szb]);

% Distance from given source location to each point of the distributed
% source sphere_e
dist = zeros(size(sphere_e));
% True point source location
src0 = [ksrc, jsrc, isrc];
for k = 1:size(sphere_e,1)
    for j = 1:size(sphere_e,2)
        for i = 1:size(sphere_e,3)
            point = [k,j,i];
            dist(k,j,i) = sqrt(sum((src0 - point).^2));
        end
    end
end

% Exponential source amplitude decay
dist4pr = exp(-(dist.^2)/2);



%% ABSORBING BOUNDARY (ABS)
% Thickness of the layer
abs_thick = min(floor(0.15*nx), floor(0.15*nz));
% Decay rate
abs_rate = 0.3/abs_thick;
% Thicknes for OX, OY and OZ directions
lmargin = [abs_thick abs_thick abs_thick];
rmargin = [abs_thick abs_thick abs_thick];
% Decay coefficients for each point of the model
weights = ones(nz+2,ny+2,nx+2);
for iz = 1:nz+2
    for iy = 1:ny+2
        for ix = 1:nx+2
            i = 0;
            j = 0;
            k = 0;
            if (ix < lmargin(1) + 1)
                i = lmargin(1) + 1 - ix;
            end
            if (iy < lmargin(2) + 1)
                j = lmargin(2) + 1 - iy;
            end
            if (iz < lmargin(3) + 1)
                k = lmargin(3) + 1 - iz;
            end
            if (nx - rmargin(1) < ix)
                i = ix - nx + rmargin(1);
            end
            if (ny - rmargin(2) < iy)
                j = iy - ny + rmargin(2);
            end
            if (nz - rmargin(3) < iz)
                k = iz - nz + rmargin(3);
            end
            if (i == 0 && j == 0 && k == 0)
                continue
            end
            rr = abs_rate * abs_rate * double(i*i + j*j + k*k);
            weights(iz,iy,ix) = exp(-rr);
        end
    end
end

%% PRINT OUT SUMMARY
fprintf('#################################################\n');
fprintf('3D elastic FDTD wave propagation in isotropic medium \nin displacement formulation with Cerjan(1985) \nboundary conditions\n');
fprintf('#################################################\n');
fprintf('Model:\n\t%d x %d x %d\tgrid nz x ny x nx\n\t%.1e x %.1e x %.1e\t[m] dz x dy x dx\n',nz,ny,nx,dz,dy,dx);
fprintf('\t%.1e x %.1e x %.1e\t[m] model size\n',nx*dx, ny*dy, nz*dz);
fprintf('\t%.1e...%.1e\t[m/s] vp\n', min(vp(:)), max(vp(:)));
fprintf('\t%.1e...%.1e\t[m/s] vs\n', min(vs(:)), max(vs(:)));
fprintf('\t%.1e...%.1e\t[kg/m3] rho\n', min(rho(:)), max(rho(:)));
fprintf('Time:\n\t%.1e\t[sec] total\n\t%.1e\t[sec] dt\n\t%d\ttime steps\n',t_total,dt,nt);
fprintf('Source:\n\t%.1e\t[Hz] dominant frequency\n\t%.1f\t[sec] index time\n',f0,t0);
fprintf('Other:\n\t%.1f\tCFL number\n', CFL);
fprintf('\t%.2f\t[m] shortest wavelength\n\t%d, %d\t points-per-wavelength OX, OZ\n', min_wavelengh, floor(min_wavelengh/dx), floor(min_wavelengh/dz));
fprintf('#################################################\n');

%% ALLOCATE MEMORY FOR THE WAVEFIELD
% +2 stands for a single ghost point for derivative computation
% from each side of the arrays
ux3 = zeros(nz+2,ny+2,nx+2);            % Wavefields at t
uy3 = zeros(nz+2,ny+2,nx+2);
uz3 = zeros(nz+2,ny+2,nx+2);
ux2 = zeros(nz+2,ny+2,nx+2);            % Wavefields at t-1
uy2 = zeros(nz+2,ny+2,nx+2);
uz2 = zeros(nz+2,ny+2,nx+2);
ux1 = zeros(nz+2,ny+2,nx+2);            % Wavefields at t-2
uy1 = zeros(nz+2,ny+2,nx+2);
uz1 = zeros(nz+2,ny+2,nx+2);

% Add ghost points to the distributed source array
dist4pr = padarray(dist4pr,[1 1 1]);

% Coefficients for derivatives
global co_dx; co_dx = 1/(2 * dx);
global co_dy; co_dy = 1/(2 * dy);
global co_dz; co_dz = 1/(2 * dz);

co_dxx = 1/dx^2;
co_dyy = 1/dy^2;
co_dzz = 1/dz^2;
co_dxy = 1/(4.0 * dx * dy);
co_dxz = 1/(4.0 * dx * dz);
co_dyz = 1/(4.0 * dy * dz);

% Some pre-computed constants
dt2rho=(dt^2)./rho;
lam_2mu = lam + 2 * mu;
lam_mu = (lam + mu);

%% Loop over TIME
tic;
for it = 1:nt
    ux3 = zeros(size(ux2));
    uy3 = zeros(size(uy2));
    uz3 = zeros(size(uz2));
    % Second-order derivatives
    % Ux
    dux_dxx = d_xx(ux2);
    dux_dyy = d_yy(ux2);
    dux_dzz = d_zz(ux2);
    dux_dxz = d_xz(ux2);
    dux_dxy = d_xy(ux2);
    % Uy
    duy_dxx = d_xx(uy2);
    duy_dyy = d_yy(uy2);
    duy_dzz = d_zz(uy2);
    duy_dxy = d_xy(uy2);
    duy_dyz = d_yz(uy2);
    % Uz
    duz_dxx = d_xx(uz2);
    duz_dyy = d_yy(uz2);
    duz_dzz = d_zz(uz2);
    duz_dxz = d_xz(uz2);
    duz_dyz = d_yz(uz2);
    % RHS of the wave equation, G
    sigmas_ux = lam_2mu .* dux_dxx + mu .* dux_dyy + mu .* dux_dzz + lam_mu .* duz_dxz + lam_mu .* duy_dxy;
    sigmas_uy = mu .* duy_dxx + lam_2mu .* duy_dyy + mu .* duy_dzz + lam_mu .* duz_dyz + lam_mu .* dux_dxy;
    sigmas_uz = mu .* duz_dxx + mu .* duz_dyy + lam_2mu .* duz_dzz + lam_mu .* duy_dyz + lam_mu .* dux_dxz;
    % U(t) = 2*U(t-1) - U(t-2) + G dt2/rho;
    ux3(2:end-1,2:end-1,2:end-1) = 2.0*ux2(2:end-1,2:end-1,2:end-1) - ux1(2:end-1,2:end-1,2:end-1) + sigmas_ux.*dt2rho;
    uy3(2:end-1,2:end-1,2:end-1) = 2.0*uy2(2:end-1,2:end-1,2:end-1) - uy1(2:end-1,2:end-1,2:end-1) + sigmas_uy.*dt2rho;
    uz3(2:end-1,2:end-1,2:end-1) = 2.0*uz2(2:end-1,2:end-1,2:end-1) - uz1(2:end-1,2:end-1,2:end-1) + sigmas_uz.*dt2rho;
%     % Add source term
    if ~mt.flag
     ux3 = ux3 + dist4pr * force_x(it);
     uy3 = uy3 + dist4pr * force_y(it);
     uz3 = uz3 + dist4pr * force_z(it);
    else
    % moment tensor as naive fources
    ux3(2:end-1,2:end-1,2:end-1) = ux3(2:end-1,2:end-1,2:end-1) + force_x(it)* ...
        (mt.xx * d_x(dist4pr) + mt.xy * d_y(dist4pr) + mt.xz * d_z(dist4pr));
    
    uy3(2:end-1,2:end-1,2:end-1) = uy3(2:end-1,2:end-1,2:end-1) + force_x(it)* ...
        (mt.yy * d_y(dist4pr) + mt.xy * d_x(dist4pr) + mt.yz * d_z(dist4pr));
    
    uz3(2:end-1,2:end-1,2:end-1) = uz3(2:end-1,2:end-1,2:end-1) + force_x(it)*...
        (mt.zz * d_z(dist4pr) + mt.yz * d_y(dist4pr) + mt.xz * d_x(dist4pr));
    end       
    % Exchange between t-2(1), t-1(2) and t(3) and apply ABS
    ux1 = ux2 .* weights;
    ux2 = ux3 .* weights;
    uy1 = uy2 .* weights;
    uy2 = uy3 .* weights;
    uz1 = uz2 .* weights;
    uz2 = uz3 .* weights;
    
    %% OUTPUT
    if mod(it,IT_DISPLAY) == 0
        fprintf('Time step: %d \t %.4f s\n',it, single(t(it)));
        % Compute amplitude of the displacement vector u
        u=sqrt(ux3.^2 + uy3.^2 + uz3.^2); up = permute(u,[2 3 1]);
        % 3D slices
        figure(1); clf; subplot(2,3,[1 2 4 5]); hold on;
        h1 = slice(up, round(nx/2), round(ny/2), round(nz/2));
        set(h1,'edgecolor','none');
        alpha(h1,0.6); axis equal tight; colormap jet;
        xlabel('OX'); ylabel('OY'); zlabel('OZ'); axis equal tight;
        title(['Step = ',num2str(it),' Time: ',sprintf('%.4f',t(it)),' sec']);
        set(gca,'ZDir','reverse'); view(52,24); grid off;
        ax_len = round(0.1 * min(nz,min(ny,nx)));
        x = line([0,ax_len],[0 0],[0,0],'color','r','linewidth',2);
        y = line([0,0],[0 ax_len],[0,0],'color','g','linewidth',2);
        z = line([0 0],[0,0],[0,ax_len],'color','b','linewidth',2);
        % Projections UX, UY, UZ onto source planes
        subplot(2,3,3); hold off;
        imagesc([
            squeeze(ux3(ksrc,:,:)) squeeze(ux3(:,jsrc,:)) squeeze(ux3(:,:,isrc));
            squeeze(uy3(ksrc,:,:)) squeeze(uy3(:,jsrc,:)) squeeze(uy3(:,:,isrc));
            squeeze(uz3(ksrc,:,:)) squeeze(uz3(:,jsrc,:)) squeeze(uz3(:,:,isrc))]);
        axis equal tight; title('XY XZ YZ slices of UX UY UZ'); colormap jet;  colorbar; drawnow;
        % Projections of U onto source planes
        subplot(2,3,6);
        h2 = imagesc([squeeze(u(ksrc,:,:)) squeeze(u(:,jsrc,:)) squeeze(u(:,:,isrc))]); axis equal tight;
        title('$$u=\sqrt{u_x^2 + u_y^2 + u_z^2}$$','Interpreter', 'Latex');
        xlabel('XY, XZ, YZ middle slices'); colorbar;
        axis equal tight; drawnow;
    end
end
toc; disp('End');

%% FUNCTIONS TO COMPUTE FIRST AND SECOND ORDER DERIVATIVES
% Add zero padding to an array
function uu = dim_plus_2(A)
uu = padarray(A,[1 1 1]);
end

% First order centered derivatives
function dA_dx = d_x(A)
global co_dx;
dA_dx = co_dx * (A(2:end-1,2:end-1,3:end) - A(2:end-1,2:end-1,1:end-2));
end

function dA_dy = d_y(A)
global co_dy;
dA_dy = co_dy * (A(2:end-1,3:end,2:end-1) - A(2:end-1,1:end-2,2:end-1));
end

function dA_dz = d_z(A)
global co_dz;
dA_dz = co_dz * (A(3:end,2:end-1,2:end-1) - A(1:end-2,2:end-1,2:end-1));
end

% Second order derivatives
function dA_dxx = d_xx(A)
dA_dxx = d_x(dim_plus_2(d_x(A)));
end

function dA_dyy = d_yy(A)
dA_dyy = d_y(dim_plus_2(d_y(A)));
end

function dA_dzz = d_zz(A)
dA_dzz = d_z(dim_plus_2(d_z(A)));
end

% Mixed derivatives
function dA_dxz = d_xz(A)
dA_dxz = d_z(dim_plus_2(d_x(A)));
end

function dA_dxy = d_xy(A)
dA_dxy = d_y(dim_plus_2(d_x(A)));
end

function dA_dyz = d_yz(A)
dA_dyz = d_z(dim_plus_2(d_y(A)));
end








