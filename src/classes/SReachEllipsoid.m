classdef SReachEllipsoid
% Creates an ellipsoid (x - c)^T Q^{-1} (x-c) <= 1
%
% SReachEllipsoid Properties:
% ---------------------------
%   center                          - Center of the ellipsoid (c)
%   shape_matrix                    - Shape matrix of the ellipsoid Q
%   dim                             - Dimension of the ellipsoid
% 
% SReachEllipsoid Methods:
% ------------------------
%   SReachEllipsoid/SReachEllipsoid - Constructor
%   disp                            - Displays critical info about the ellipsoid
%   mtimes                          - Multiplication of ellipsoid by a matrix
%   support                         - Support function of the ellipsoid
% 
% Notes:
% ------
% * The ellipsoid can be full-dimensional (Q non-singular) or be a 
%   lower-dimensional ellipsoid embedded in a high dimensional space (Q 
%   singular)
% * F * SReachEllipsoid, SReachEllipsoid * F is supported for an n x dim -
%   dimensional matrix
%
% ===========================================================================
%
% This function is part of the Stochastic Reachability Toolbox.
% License for the use of this function is given in
%      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
% 
% 

    properties
        % SReachEllipsoid/center
        % ==================================================================
        % 
        % Column vector indicating the center of the ellipsoid
        %
        center

        % SReachEllipsoid/shape_matrix
        % ==================================================================
        % 
        % Shape matrix for the ellipsoid
        % 
        shape_matrix

        % SReachEllipsoid/dim
        % ==================================================================
        % 
        % Dimension of the ellipsoid dimension
        % 
        dim
    end
    methods
        function obj = SReachEllipsoid(center, shape_matrix)
        %  Constructor for SReachEllipsoid class
        % ====================================================================
        %
        % Inputs:
        % -------
        %   center       - Center of the ellipsoid
        %   shape_matrix - Shape matrix of the ellipsoid
        %
        % Outputs:
        % --------
        %   obj          - SReachEllipsoid object
        %
        % =====================================================================
        % 
        % This function is part of the Stochastic Reachability Toolbox.
        % License for the use of this function is given in
        %      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
        % 
        % 
        
            % Input parsing
            inpar = inputParser();
            inpar.addRequired('center', @(x) validateattributes(x,...
                {'numeric'}, {'column','nonempty'}));
            inpar.addRequired('shape_matrix', @(x) validateattributes(x,...
                {'numeric'}, {'square','nonempty'}));

            try
                inpar.parse(center, shape_matrix);
            catch err
                exc = SrtInvalidArgsError.withFunctionName();
                exc = exc.addCause(err);
                throwAsCaller(exc);
            end
            
            obj.center = center;
            obj.shape_matrix = shape_matrix;
            obj.dim = size(obj.center,1);

            % Check if the center and shape_matrix are of correct dimensions
            if size(obj.center, 1) ~= size(obj.shape_matrix, 1)
                throwAsCaller(SrtInvalidArgsError(['Center and shape matrix',...
                    ' have different dimensions']));
            end
            if ~issymmetric(shape_matrix)
                % Compute the symmetric component of it
                symm_shape_matrix = (shape_matrix+shape_matrix')/2;
                % Max error element-wise
                max_err = max(max(abs(shape_matrix - symm_shape_matrix)));
                if max_err > eps
                    warning('SReachTools:runtime',sprintf(['Non-symmetric ', ...
                        'shape matrix made symmetric (max element-wise',...
                        ' error: %1.3e)!'], max_err));
                end
                obj.shape_matrix = symm_shape_matrix;
            end
            % For some reason, -eps alone is not enough?
            min_eig_val = min(eig(obj.shape_matrix));
            if  min_eig_val <= -2*eps
                throwAsCaller(SrtInvalidArgsError(['Covariance ',...
                    'matrix can not have negative eigenvalues']));
            elseif min_eig_val <= eps
                warning('SReachTools:runtime',['Creating a',...
                    ' Gaussian which might have a deterministic ',...
                    'component']);
            end
        end

        
        function disp(obj)
        % Override of MATLAB internal display
        % ====================================================================
        % 
        % Overriding of MATLAB built-in display function for the class
        %
        % ====================================================================
        % 
        % This function is part of the Stochastic Reachability Toolbox.
        % License for the use of this function is given in
        %      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
        % 
        %
            
            fprintf('%d-dimensional ellipsoid\n', obj.dim);
        end
        
        function val = support(obj, l)
        % Support function of the ellipsoid object
        % ====================================================================
        %
        % Inputs:
        % -------
        %   l   - A query column vector or a collection of query vectors stacked 
        %         as rows
        %
        % Outputs:
        % --------
        %   val - max_{y \in ellipsoid} l'*y
        %
        % =====================================================================
        % 
        % This function is part of the Stochastic Reachability Toolbox.
        % License for the use of this function is given in
        %      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
        % 
        % 
        
            if size(l,1) ~= obj.dim
                throwAsCaller(SrtInvalidArgsError('l has incorrect dimensions.'));
            end
            % cholesky > obj.shape_matrix = sqrt_shape_matrix'*sqrt_shape_matrix
            [sqrt_shape_matrix, p] = chol(obj.shape_matrix);    
            if p > 0
                % Non-positive definite matrix can not use Cholesky's decompose
                % Use sqrt to obtain a symmetric non-sparse square-root matrix
                sqrt_shape_matrix = sqrt(obj.shape_matrix);
            end
            % Hence, we need the transpose
            val = l'* obj.center + norms(l'*sqrt_shape_matrix', 2,2);
        end
        
        function newobj=mtimes(obj, F)
        % Override of MATLAB multiplication command
        % ====================================================================
        % 
        % Inputs:
        % -------
        %   obj - SReachEllipsoid object
        %   F   - Linear transformation matrix for multiplication
        %
        % Outputs:
        % --------
        %   newobj - SReachEllipsoid object (F*obj)
        %
        % ====================================================================
        % 
        % This function is part of the Stochastic Reachability Toolbox.
        % License for the use of this function is given in
        %      https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
        % 
        %
            
            switch [class(obj), class(F)]
                case ['SReachEllipsoid','double']
                    % All ok
                case ['double', 'SReachEllipsoid']
                    % Need to switch the arguments
                    Ftemp = obj;
                    obj = F;
                    F = Ftemp;
                otherwise
                    throwAsCaller(SrtInvalidArgsError(sprintf(['Operation *',...
                       ' not defined between *%s, %s'], class(obj), class(F))));
            end
            newobj=SReachEllipsoid(F * obj.center, F * obj.shape_matrix * F');            
        end
    end
end
