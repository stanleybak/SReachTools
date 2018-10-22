function reach_prob = computeReachProb(input_vector, ...
    mean_X_sans_input, cov_X_sans_input, H, concat_target_tube_A, ...
    concat_target_tube_b, desired_accuracy)
% Compute reach prob using Genz's algorithm (Internal function)
% =============================================================================
%
% computeReachProb computes the integral of the Gaussian random vector
% (concatenated state vector) X over the (polytopic) safety tube. It is used for
% evaluation of the objective function of the Fourier transform-based
% underapproximation of the terminal hitting-time stochastic reach-avoid problem
% as discussed in
%
% A. Vinod and M. Oishi, "Scalable Underapproximation for Stochastic
% Reach-Avoid Problem for High-Dimensional LTI Systems using Fourier
% Transforms," in IEEE Control Systems Letters (L-CSS), 2017.
%
% =============================================================================
%
% reach_prob = computeReachProb(input_vector, ...
%    mean_X_sans_input, cov_X_sans_input, H, concat_target_tube_A, ...
%    concat_target_tube_b, desired_accuracy)
% 
% Inputs:
% -------
%   input_vector         - Concatenated input vector under investigation
%   mean_X_sans_input    - Mean of (X - H * input_vector)
%   cov_X_sans_input     - Covariance matrix of X (Since addition of a constant
%                          to a Gaussian doesn't affect the covariance matrix)
%   H                    - Concatenated H matrix, See @LtiSystem/getConcatMats.m
%   concat_target_tube_A - concatenated target tube polyhedral definition
%   concat_target_tube_b - concatenated target tube polyhedral definition
%   desired_accuracy     - Accuracy expected for the integral of the Gaussian
%                          random vector X over the concatenated_target_tube
%
% Outputs:
% --------
%   reach_avoid_prob     - Reach probability
%
% See also iteratedQscmvnv.
%
% Notes:
% ------
% * MATLAB DEPENDENCY: Uses MATLAB's Statistics and Machine Learning Toolbox.
%                      Need normpdf, norminv, normcdf for Genz's algorithm
% * Uses Genz's algorithm in an interative manner to compute the integral of a
%   Gaussian over a polytope to desired_accuracy provided. See
%   helperFunctions/iteratedQscmvnv.m for more details.
% * In the event, the integral is below the desired_accuracy, reach_prob is set
%   to desired_accuracy. This is to allow to take log of the reach_prob.
% 
% =============================================================================
% 
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
%
%

    % Construct the mean and covariance of the Gaussian random vector X
    mean_X = mean_X_sans_input + H * input_vector;
    cov_X = cov_X_sans_input;

    % Construct the concatenated target tube polytope for qscmvnv
    qscmvnv_polytope_lower_bound  = repmat(-Inf, ...
        [size(concat_target_tube_A, 1), 1]);
    qscmvnv_polytope_coeff_matrix = concat_target_tube_A;
    qscmvnv_polytope_upper_bound  = concat_target_tube_b - ...
                                            concat_target_tube_A * mean_X;

    %% QSCMVNV in a loop using the error estimate
    try
        reach_prob = iteratedQscmvnv(cov_X, qscmvnv_polytope_lower_bound, ...
            qscmvnv_polytope_coeff_matrix, qscmvnv_polytope_upper_bound, ...
            desired_accuracy, 10);
    catch %ME
        err = SrtInvalidArgsError(['Errored in Genz''s algorithm! This', ...
            ' may be because the covariance matrix is not symmetric.\nTry', ...
            ' providing (matrix + matrix'')/2 instead.']);
        throw(err);
    end
end
