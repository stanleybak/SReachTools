function [maximum_underapproximate_reach_avoid_probability, ...
          xmax, ...
          optimal_input_vector_for_xmax] = ...
                     computeXmaxForStochReachAvoidSetUnderapprox(...
                                      sys, ...
                                      time_horizon, ...
                                      safe_set, ...
                                      concat_input_space_A, ... 
                                      concat_input_space_b, ...
                                      concat_target_tube_A, ... 
                                      concat_target_tube_b, ...
                                      Abar, ...
                                      H, ...
                                      mean_X_sans_input_sans_initial_state, ...
                                      cov_X_sans_input, ...
                                      affine_hull_of_interest_2D, ...
                                      desired_accuracy, ...
                                      PSoptions)
% SReachTools/stochasticReachAvoid/computeXmaxForStochReachAvoidSetUnderapprox: 
% Computes the maximum attainable stochastic reach-avoid probability using 
% open-loop controllers (Internal function --- assumes arguments are all ok)
% ====================================================================================
%
% computeXmaxForStochReachAvoidSetUnderapprox computes the initial
% state x_max and its associated open-loop vector that maximizes the Fourier
% transform-based underapproximation to the terminal hitting-time stochastic
% reach-avoid problem discussed in
%
% A. Vinod, and M. Oishi, "Scalable Underapproximative Verification of
% Stochastic LTI Systems Using Convexity and Compactness," in Proceedings of
% Hybrid Systems: Computation and Control (HSCC), 2018. 
%
% It first initializes for an xmax that is deepest with a feasible input_vector
% that keeps the mean trajectory within the reach-avoid tube. This initial guess
% is then refined using patternsearch.
%
% USAGE: This function is not intended for public use. See
% getFtBasedUnderapproxStochReachAvoidSet
%
% ==============================================================================
% [maximum_underapproximate_reach_avoid_probability, ...
%  xmax, ...
%  optimal_input_vector_for_xmax] = ...
%                    computeXmaxForStochReachAvoidSetUnderapprox(...
%                                     sys, ...
%                                     time_horizon, ...
%                                     safe_set, ...
%                                     concat_input_space_A, ... 
%                                     concat_input_space_b, ...
%                                     concat_target_tube_A, ... 
%                                     concat_target_tube_b, ...
%                                     Abar, ...
%                                     H, ...
%                                     mean_X_sans_input_sans_initial_state, ...
%                                     cov_X_sans_input, ...
%                                     affine_hull_of_interest_2D, ...
%                                     desired_accuracy, ...
%                                     PSoptions)
%
% Inputs:
% -------
%  sys                          - LtiSystem object describing the system to be
%                                 verified
%  time_horizon                 - Time horizon of the stochastic reach-avoid
%                                 problem
%  initial_state                - Initial state of interest
%  safe_set                     - Safe set for stochastic reach-avoid problem
%  concat_input_space_A,  
%   concat_input_space_b        - (A,b) Halfspace representation for the
%                                 polytope U^{time_horizon} set.        
%  concat_target_tube_A,  
%   concat_target_tube_b        - (A,b) Halfspace representation for the
%                                 target tube. For example, the terminal
%                                 reach-avoid problem requires a polytope of the
%                                 form safe_set^{time_horizon-1} x target_set.        
%  Abar                         - Concatenated state matrix (see
%                                 @LtiSystem/getConcatMats for the
%                                 notation used in next three inputs)
%  H                            - Concatenated input matrix
%  mean_X_sans_input_sans_initial_state
%                               - Mean of X w\ zero input under the disturbance
%  cov_X_sans_input             - Covariance of X w\ zero input under the
%                                 disturbance
%  affine_hull_of_interest_2D
%                               - Affine hull whose slice of the stochastic
%                                 reach-avoid set is of interest
%                                 Dimension of state_dimension-2 
%                                 Define this by Polyhedron('He',[A_eq, b_eq])
%  desired_accuracy             - Accuracy
%  PSoptions                    - Options for patternsearch 
%
% Outputs:
% --------
%  maximum_underapproximate_reach_avoid_probability
%                               - Maximum terminal hitting-time stochastic
%                                 reach-avoid probability that may be attained
%                                 via an open-loop controller
%  xmax                         - Initial state that attains this maximum
%  optimal_input_vector_for_xmax- Optimal input vector for xmax
%
% See also verificationOfCwhDynamics,
% getFtBasedUnderapproxStochReachAvoidSet,
% reachAvoidProbAssumingValidInitialState
%
% Notes:
% ------
% * NOT ACTIVELY TESTED: Builds on other tested functions.
% * MATLAB DEPENDENCY: Uses MATLAB's Global Optimization Toolbox; Statistics and
%                      Machine Learning Toolbox.
%                      Needs patternsearch for gradient-free optimization
%                      Needs normpdf, normcdf, norminv for Genz's algorithm
% * EXTERNAL DEPENDENCY: Uses MPT3 and CVX
%                      Needs MPT3 for defining a controlled system and the
%                      definition of the safe and the target (polytopic) sets
%                      Needs CVX to setup convex optimization problems that
%                      initializes the patternsearch-based optimization
% * See @LtiSystem/getConcatMats for more information about the
%     notation used.
%
% ==============================================================================
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/abyvinod/SReachTools/blob/master/LICENSE
%
%

    %% Compute an initialization for the input vector and xmax for patternsearch
    length_state_vector = sys.state_dimension * time_horizon;
    length_input_vector = sys.input_dimension * time_horizon;
    dual_norm_of_safe_set_A = sqrt(diag(safe_set.A*safe_set.A')); 
    % maximize R - 0.01 |U| 
    % subject to
    %   X = Abar x_0 + H * U + G_matrix * \mu_W 
    %   U \in \mathcal{U}^N
    %   X \in concatenated_target_tube
    %   x_0\in AffineHull
    %   safe_set.A_i * x_0 + R* || safe_set.A_i || \leq b_i 
    %                                      (see Boyd's CVX textbook, pg. 418,
    %                                       Chebyshev centering for a polytope)
    cvx_begin quiet
        variable resulting_X_for_xmax(length_state_vector) 
        variable guess_concatentated_input_vector(length_input_vector)
        variable initial_x_for_xmax(sys.state_dimension)
        variable R

        maximize R - 0.01 * norm(guess_concatentated_input_vector)

        subject to
            R >= 0
            resulting_X_for_xmax == (Abar * initial_x_for_xmax ...
                            + H * guess_concatentated_input_vector...
                            + mean_X_sans_input_sans_initial_state)
            concat_input_space_A * guess_concatentated_input_vector <= ...
                                                      concat_input_space_b 
            concat_target_tube_A * resulting_X_for_xmax <= ...
                            concat_target_tube_b
            affine_hull_of_interest_2D.Ae * initial_x_for_xmax == ...
                                                   affine_hull_of_interest_2D.be
            for i = 1:length(safe_set.A)
                safe_set.A(i,:) * initial_x_for_xmax...
                              + R * dual_norm_of_safe_set_A(i) <= safe_set.b(i)
            end
    cvx_end
    initial_guess_input_vector_and_xmax = [guess_concatentated_input_vector;
                                           initial_x_for_xmax];
    
    % Construct the reach-avoid cost function: -log(ReachAvoidProbability(U))
    negativeLogReachAvoidProbabilityGivenInputVectorInitialState = ...
      @(input_vector_and_xmax)...
      -log(reachAvoidProbAssumingValidInitialState(...
                input_vector_and_xmax(1: sys.input_dimension * time_horizon), ...
                Abar * input_vector_and_xmax(...
                    sys.input_dimension * time_horizon + 1: end) ...
                    + mean_X_sans_input_sans_initial_state, ...
                cov_X_sans_input, ...
                H, ...
                concat_target_tube_A, ...
                concat_target_tube_b, ...
                desired_accuracy));
    
    % Constraint generation --- decision variable [input_vector;xmax]
    input_vector_augmented_affine_hull_Aeq = ...
        [zeros(size(affine_hull_of_interest_2D.Ae,1), ...
                            sys.input_dimension * time_horizon), ...
                                                 affine_hull_of_interest_2D.Ae];
    input_vector_augmented_affine_hull_beq = affine_hull_of_interest_2D.be;
    input_vector_augmented_safe_Aineq = blkdiag(concat_input_space_A, ...
                                                safe_set.A);
    input_vector_augmented_safe_bineq = [concat_input_space_b;
                                         safe_set.b];

    % Compute xmax, the input policy, and the max reach-avoid probability
    [optimal_input_vector_and_xmax, ...
     optimal_negative_log_reach_avoid_probability]= ...
              patternsearch(...
                negativeLogReachAvoidProbabilityGivenInputVectorInitialState, ...
                initial_guess_input_vector_and_xmax, ...
                input_vector_augmented_safe_Aineq, ...
                input_vector_augmented_safe_bineq, ...
                input_vector_augmented_affine_hull_Aeq, ...
                input_vector_augmented_affine_hull_beq, ...
                [],[],[], ...
                PSoptions);
    
    %% Parse the output of patternsearch
    % Maximum attainable terminal hitting-time stochastic reach-avoid
    % probability using open-loop controller
    maximum_underapproximate_reach_avoid_probability = ...
                         exp(-optimal_negative_log_reach_avoid_probability);
    % Optimal open_loop_control_policy
    optimal_input_vector_for_xmax = optimal_input_vector_and_xmax(1:...
                                            sys.input_dimension * time_horizon);
    % Corresponding xmax
    xmax = optimal_input_vector_and_xmax(...
                sys.input_dimension * time_horizon + 1: end);
end

