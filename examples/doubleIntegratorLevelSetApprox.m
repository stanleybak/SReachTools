% SReach/doubleIntegratorLevelSetApprox  Doulbe integrator level set 
% approximation
% ============================================================================
%
% This script is an example application of using SReach to compute
% underapproximations of the stochastic beta level set for a viability target
% tube. The problem is based off of the double integrator example in [1].
%
% [1] - J. Gleason, A. P. Vinod, and M. M. K. Oishi, "Underapproximation of
%       Reach-Avoid Sets for Discrete-Time Stochastic Systems via Lagrangian
%       Methods," in Proceedings of IEEE Conference on Decision and Control
%       (CDC), Melbourne, Australia, 2017.
%
% ============================================================================
% 
% This function is part of the Stochastic Optimal Control Toolbox.
% License for the use of this function is given in
%      https://github.com/abyvinod/SReach/blob/master/LICENSE
% 
% 

% example parameters
T = 0.25;

% define the system
sys = LtiSystem('StateMatrix', [1, T; 0, 1], ...
    'InputMatrix', [T^2/2; T], ...
    'InputSpace', Polyhedron('lb', -0.1, 'ub', 0.1), ...
    'DisturbanceMatrix', eye(2), ...
    'Disturbance', StochasticDisturbance('Gaussian', zeros(2,1), 0.005*eye(2)));

% solving the "viability" problem means we want the system to stay within a set
% of safe states
% safe set definition
safe_set = Polyhedron('lb', [-1, -1], 'ub', [1, 1]);

% in target tube for the viability problem is equivalent to a tube of repeating
% safe sets
target_tube = {safe_set, ...
    safe_set, ...
    safe_set, ...
    safe_set, ...
    safe_set, ...
    safe_set};

N = length(target_tube);

% want to solve for the approximate level set for 1--5 total time steps, this is
% done by repeatedly calling the function to get the approximate level set since
% the bouded disturbance set changes depending on the length of the 
% horizon/target tube

% start simulation timer
sim_timer = tic;

hf = figure();
for i = 2:N
    % going to use the random vector method for obtaining the approximation of
    % the ellipse for the gaussian disturbance
    approx_level_set = getApproxStochasticLevelSetViaLagrangian(sys, ...
        0.8, ...
        target_tube(1:i), ...
        'underapproximation', ...
        'random', 100);
    
    % some plotting functions
    subplot(1, N-1, i-1)
    plot(safe_set, 'Color', 'y')
    hold on;
    plot(approx_level_set, 'Color', 'g')
    hold off;
end

% stop timer
exec_time = toc(sim_timer);

fprintf('Total computation time for level sets: %.3f s\n', exec_time);