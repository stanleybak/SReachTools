function [concatenated_target_tube_A, concatenated_target_tube_b] =...
                                        getConcatTargetTube(safe_set,...
                                                                  target_set,...
                                                                  time_horizon)
% SReach/stochasticReachAvoid/getConcatTargetTube: Get concatenated
% target tube
% ============================================================================
%
% getConcatTargetTube computes the concatenated target tube,
% safe_set^{time_horizon -1 } x target_set, a huge polyhedron in the
% (sys.state_dimension x time_horizon)-dimensional Euclidean space.
% The output matrices satisfy the relation that the a concatenated state vector
% X lies in the reach-avoid tube if and only if
% 
% concatenated_target_tube_A * X <= concatenated_target_tube_b 
%
% Usage: See getFtLowerBoundStochasticReachAvoid.
%
% ============================================================================
%
% [concatenated_target_tube_A, ...
%     concatenated_target_tube_b] = getConcatTargetTube(safe_set,...
%                                                             target_set,...
%                                                             time_horizon)
% 
% Inputs:
% -------
%   time_horizon    - Time horizon of the stochastic reach-avoid problem
%   safe_set        - Safe set for the stochastic reach-avoid problem
%   target_set      - Target set for the stochastic reach-avoid problem
%
% Outputs:
% --------
%   concatenated_target_tube_A - State matrix concatenated for target tube
%   concatenated_target_tube_b - Input matrix concatenated for target tube
%
% Notes:
% ------
% * This function also serves as a delegatee for input handling.
% 
% ============================================================================
% 
% This function is part of the Stochastic Optimal Control Toolbox.
% License for the use of this function is given in
%      https://github.com/abyvinod/SReach/blob/master/LICENSE
%
%

    %% Input handling
    % Ensure that the target and safe sets are non-empty polyhedron of same
    % dimension
    assert(isa(target_set, 'Polyhedron') && ~target_set.isEmptySet(),...
           'SReach:invalidArgs',...
           'Target set must be a non-empty polyhedron');
    assert(isa(safe_set, 'Polyhedron') && ~safe_set.isEmptySet(),...
           'SReach:invalidArgs',...
           'Safe set must be a non-empty polyhedron');
    assert(safe_set.Dim == target_set.Dim,...
           'SReach:invalidArgs',...
           'Safe and target sets must be of the same dimension');
    % Ensure that time horizon is a scalar and positive
    assert( isscalar(time_horizon) && time_horizon > 0,...
           'SReach:invalidArgs',...
           'Expected a scalar positive time_horizon');

    %% Construction of the concatenated target tube
    concatenated_target_tube_A = blkdiag(...
                                 kron(eye(time_horizon-1),safe_set.A),...
                                 target_set.A);
    concatenated_target_tube_b = [kron(ones(time_horizon-1,1), safe_set.b);
                                  target_set.b];
end

