function [concat_input_space_A, concat_input_space_b] = ...
                                         getConcatInputSpace(sys, ...
                                                             time_horizon)
% SReachTools/LtiSystem/getConcatInputSpace: Get half space representation of
% the concatenated (polytopic) input space for the given time horizon
% ============================================================================
% 
% Computes the input_space^{time_horizon} corresponding to a given set, which
% is the set of admissible open-loop control polices. This function computes the
% half-space representation of the cartesian products of polytopic input spaces.
%
% Usage:
% ------
%
% % Compute the (matrix form) set of admissible open-loop control policies given
% % a LtiSystem and a time horizon
%
% sys = LtiSystem(...
%     'StateMatrix', eye(2), ...
%     'InputMatrix', ones(2,1), ...
%     'InputSpace', Polyhedron('lb', -umax, 'ub', umax));
% time_horizon = 10;
% [concat_input_space_A, concat_input_space_b] = ...
%                                             getConcatInputSpace(sys, ...
%                                                                 time_horizon);
% 
% ============================================================================
%
% [concat_input_space_A, concat_input_space_b] =...
%                                              getConcatInputSpace(sys, ...
%                                                                  time_horizon)
% 
% Inputs:
% -------
%   sys                  - An object of LtiSystem class 
%   time_horizon         - Time horizon
%
% Outputs:
% --------
%   concat_input_space_A, concat_input_space_b 
%                        - Concatenated input space (Halfspace representation)
%
% =============================================================================
%
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/abyvinod/SReachTools/blob/master/LICENSE
% 
%

    %% Input handling
    % Ensure that the system has a non-empty input space
    assert(~sys.input_space.isEmptySet, ...
           'SReachTools:invalidArgs', ...
           'Expected a non-empty polyhedral input space');
    % Ensure that time horizon is a scalar and positive
    assert( isscalar(time_horizon) && time_horizon > 0, ...
           'SReachTools:invalidArgs', ...
           'Expected a scalar positive time_horizon');

    %% Construction of the concatenated input space (input_space^{time_horizon})
    concat_input_space_A = kron(eye(time_horizon), sys.input_space.A);
    concat_input_space_b = kron(ones(time_horizon,1), sys.input_space.b);
end
