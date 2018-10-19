classdef SrtBaseException < MException
% Custom exception object for SReachTools internal errors
% ============================================================================
% 
% Customized class for generating SReachTools internal errors, subclass of the 
% standard MATLAB MException class
%
% Usage:
% ------
% exc = SrtBaseException('error message')
%
% ============================================================================
%
% See also MException
%
% ============================================================================
%
%   This function is part of the Stochastic Optimal Control Toolbox.
%   License for the use of this function is given in
%        https://github.com/unm-hscl/SReachTools/blob/master/LICENSE
% 
    
    properties (Access = private)
        mnemonic = '';
    end
    
    methods
        function obj = SrtBaseException(id, varargin)
            obj@MException(sprintf('SReachTools:%s', id), ''); 
            if length(varargin) >= 1
                obj.message = sprintf(varargin{:});
            end

            obj.mnemonic = id;
        end
    end

    methods (Static)
        function comp = getErrorComponent()
            comp = 'SReachTools';
        end
    end
end
