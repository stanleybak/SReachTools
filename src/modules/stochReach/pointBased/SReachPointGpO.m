function [lb_stoch_reach, opt_input_vec] = SReachPointGpO(sys, initial_state,...
    safety_tube, options)
% Solve the stochastic reach-avoid problem (lower bound on the probability and 
% an open-loop controller synthesis) using Genz's algorithm and MATLAB's
% patternsearch (a nonlinear, derivative-free, constrained optimization solver)
% =============================================================================
%
% SReachPointGpO implements the Fourier transform-based underapproximation to
% the stochastic reachability of the target tube problem. A simpler reach-avoid
% problem formulation was discussed in
%
% A. Vinod and M. Oishi, "Scalable Underapproximation for Stochastic
% Reach-Avoid Problem for High-Dimensional LTI Systems using Fourier
% Transforms," in IEEE Control Systems Letters (L-CSS), 2017.
%
% =============================================================================
%
%  [lb_stoch_reach, opt_input_vec] = SReachPointGpO(sys, initial_state,...
%      safety_tube, options)
%
% Inputs:
% -------
%   sys          - System description (LtvSystem/LtiSystem object)
%   initial_state- Initial state for which the maximal reach probability must be
%                  evaluated (A numeric vector of dimension sys.state_dim)
%   safety_tube  - Collection of (potentially time-varying) safe sets that
%                  define the safe states (Tube object)
%   options      - Collection of user-specified options for 'genzps-open'
%                  (Matlab struct created using SReachPointOptions)
%
% Outputs:
% --------
%   lb_stoch_reach 
%               - Lower bound on the stochastic reachability of a target tube
%                   problem computed using convex chance constraints and
%                   piecewise affine approximation
%   opt_input_vec
%               - Open-loop controller: column vector of dimension
%                 (sys.input_dim*N) x 1
%
% See also SReachPoint.
%
% Notes:
% ------
% * Uses SReachPoint('term','chance-open',...) for initialization of
%   patternsearch
% * Uses Genz's algorithm (see in src/helperFunctions) instead of MATLAB's
%   Statistics and Machine Learning Toolbox's mvncdf to compute the integral of
%   the Gaussian over a polytope
% * See @LtiSystem/getConcatMats for more information about the notation used.
% 
% ============================================================================
% 
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
% 
%

    % INPUT HANDLING as well as necessary data creation
    optionsCc = SReachPointOptions('term', 'chance-open');
    optionsCc.desired_accuracy = options.desired_accuracy;
    [guess_lb_stoch_reach, guess_opt_input_vec, ~, extra_info] =...
        SReachPointCcO(sys, initial_state, safety_tube, optionsCc);

    % Unpack the other necessary data from SReachPointCcO
    concat_safety_tube_A = extra_info.concat_safety_tube_A;
    concat_safety_tube_b = extra_info.concat_safety_tube_b;
    concat_input_space_A = extra_info.concat_input_space_A;
    concat_input_space_b = extra_info.concat_input_space_b;
    H = extra_info.H;
    mean_X_sans_input = extra_info.mean_X_sans_input;
    cov_X_sans_input = extra_info.cov_X_sans_input;

    % Ensure options is good
    otherInputHandling(options);
    
    if guess_lb_stoch_reach < 0
        % Chance constrained approach failed to find an optimal open-loop
        % controller => Try just getting the mean to be as safe as possible
        % 
        % minimize ||s||_1
        % subject to 
        %                               mean_X = mean_X_sans_input + H U
        %  concatenated_safety_tube.A * mean_X <= concatenated_safety_tube.b + s   
        %                                                (Softened reach const.)
        %       concatenated_input_space.A * U <= concatenated_input_space.b
        %
        % Here, mean_X_sans_input is concatenated_A_matrix * x_0 + G_matrix *
        % concatenated_mean_vector_for_the_disturbance (see 
        % @LtiSystem/getConcatMats for more information on the notation)
        %
        % OVERWRITE the guess_opt_input_vec solution from SReachPointCcO
        cvx_begin quiet
            variable U(sys.input_dim * time_horizon,1)
            variable mean_X(sys.state_dim * time_horizon,1)
            variable slack_vars(length(concat_safety_tube_b))
            minimize norm(slack_vars)
            subject to
                mean_X == mean_X_sans_input + H * U;
                concat_safety_tube_A * mean_X <= concat_safety_tube_b...
                                                    + slack_vars;
                concat_input_space_A * U <= concat_input_space_b;
        cvx_end
        if strcmpi(cvx_status,'Solved') && norm(slack_variable) < 1e-2
            % We have an initial solution to work with
            guess_lb_stoch_reach = 0;
        end
    end

    if guess_lb_stoch_reach < 0
        %% No initial solution to work with
        lb_stoch_reach = -1;
        opt_input_vec = nan(sys.input_dim * time_horizon, 1);
    else
        %% Got an initial solution to work with
        % Construct the reach cost function: 
        % 
        % -log(ReachProb(U)) = -log(\int_{safety_tube} \psi_{\bX}(Z; x_0, U) dZ
        negLogReachProbGivenInputVec= @(input_vec)-log(computeReachProb(...
            input_vec, mean_X_sans_input, cov_X_sans_input, H, ...
            concat_safety_tube_A, concat_safety_tube_b,...
            options.desired_accuracy));

        % Compute the optimal admissible input_vec that minimizes
        % negLogReachProbGivenInputVec(input_vec) given x_0 | We use
        % patternsearch because negLogReachProbGivenInputVec can be noisy
        % due to its reliance on Monte Carlo simulation
        %
        % minimize -log(ReachProb(U))
        % subject to
        %        concat_input_space_A * U <= concat_input_space_b
        [opt_input_vec, opt_neg_log_reach_prob]= ...
            patternsearch(negLogReachProbGivenInputVec, guess_opt_input_vec, ...
                concat_input_space_A, concat_input_space_b, [],[],[],[],[],...
                options.PSoptions);
        
        % Compute the lower bound and the optimal open_loop_control_policy
        lb_stoch_reach = exp(-opt_neg_log_reach_prob);
    end
end

function otherInputHandling(options)
    if ~(strcmpi(options.prob_str, 'term') &&...
            strcmpi(options.method_str, 'genzps-open'))
        throwAsCaller(SrtInvalidArgsError('Invalid options provided'));
    end
end
