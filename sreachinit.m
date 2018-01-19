function varargout = sreachinit(varargin)
% SReach/sreachinit: Initialization function
% ======================================================================
%
%   Function to initialize and add source functions of the SReach toolbox
%   to the path.
%
%   Usage:
%   ------
%   sreachinit
%   sreachinit('--options');
%
% ======================================================================
% 
% sreachinit options
% sreachinit('options');
%
% Inputs:
%   Available options:
%       -v, --verbose    Have initalization function explicitly print to
%                        console which folders are being added to the path
%       -x, --deinit     Remove SReach toolbox folders from the path
%       -t, --test       Perform unit testing after initialization or deinit
%       -T               Perform unit testing without initialization or deinit,
%                        will cancel out any other parameters, e.g. '-x', '-v'
%
% Outputs:
%   None
%
% Notes:
%   - Performing a deinit and testing '-x -t' will deinit the SReach toolbox and
%     then perform unit testing, causing all unit tests to fail.
% 
% =========================================================================
% 
%   This function is part of the Stochastic Optimal Control Toolbox.
%   License for the use of this function is given in
%        https://github.com/abyvinod/SReach/blob/master/LICENSE
% 
% 

    verbose   = false;
    deinit    = false;
    run_tests = false;
    
    for i = 1:length(varargin)
        if strcmp(varargin{i}, '-v') || strcmp(varargin{i}, '--verbose')
            verbose = true;
        elseif strcmp(varargin{i}, '-x') || strcmp(varargin{i}, '--deinit')
            deinit = true;
        elseif strcmp(varargin{i}, '-t') || strcmp(varargin{i}, '--test')
            run_tests = true;
        elseif strcmp(varargin{i}, '-T')
            test_results = sreachtest();
            if nargout == 1
                varargout{1} = test_results;
            end
            return;
        else
            assert(false, 'Invalid input option, see help sreachinit')
        end
    end
    
    % get the parent dir of this function
    script_path = fileparts(mfilename('fullpath'));
    
    % absolute path to the SReach src directory
    src_path = fullfile(script_path, 'src');
    ex_path = fullfile(script_path, 'examples');
    
    if ismac                            % MAC (TODO: Untested)
        % new paths to add
        new_paths = strsplit([script_path ';' genpath(src_path), ...
            genpath(ex_path)], ';');
   
        % current MATLAB folders on path
        p = path;
        path_cell = split(p, ';');
    elseif ispc                         % WINDOWS
        % new paths to add
        new_paths = strsplit([script_path ';' genpath(src_path), ...
            genpath(ex_path)], ';');
   
        % current MATLAB folders on path
        p = path;
        path_cell = split(p, ';');
    elseif isunix                       % UNIX
        % new paths to add
        new_paths = strsplit([script_path ':' genpath(src_path), ...
            genpath(ex_path)], ':');
   
        % current MATLAB folders on path
        p = path;
        path_cell = split(p, ':');
    else
        disp('Platform not supported')
    end 
    if ~deinit
        % add paths
        for i = 1:length(new_paths) - 1
            if ~ismember(new_paths{i}, path_cell)
                if verbose
                    fprintf('Adding to path: %s\n', new_paths{i});
                end
                addpath(new_paths{i});
            end
        end
    else
        % remove paths
        for i = 1:length(new_paths) - 1
            if ismember(new_paths{i}, path_cell)
                if verbose
                    fprintf('Removing from path: %s\n', new_paths{i});
                end
                rmpath(new_paths{i});
            end
        end
    end
    
    if run_tests
        sreachtest();
    end

end

function test_results = sreachtest()

    % get the parent dir of this function
    script_path = mfilename('fullpath');

    % trick - mfile name will output /path/to/the/file/sreachinit, so as a hack can
    % simply remove the /sreachinit (11 chars) to get the path
    % if MATLAB changes the way mfilename works then this hack will not work
    script_path = script_path(1:end-11);
    
    current_dir = pwd;
    
    cd(fullfile(script_path, 'tests'));
    test_results = runtests();
    disp(test_results)
    cd(current_dir);
end
