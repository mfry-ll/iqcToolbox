%% Requirements:
% 1. lftToRct shall convert time-invariant Ulft to uss, umat, or ss objects
% 2. lftToRct shall map all non-convertible Delta objects to udyn objects and
%     provide an additional output remapping each udyn object to its original
%     Delta object
% 3. lftToRct shall throw an error if provided an invalid object or an object 
%     that doesn't have a [0 1] horizon_period

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for lftToRct
classdef (TestTags = {'RCT'}) testLftToRct < matlab.unittest.TestCase
    
methods (TestMethodSetup)
function seedAndReportRng(testCase)
seed = floor(posixtime(datetime('now')));
rng(seed, 'twister');
diagnose_str = ...
    sprintf(['Random inputs may be regenerated by calling: \n',...
             '>> rng(%10d) \n',...
             'before running the remainder of the test''s body'],...
            seed);
testCase.onFailure(@() fprintf(diagnose_str));
end    
end
    
methods(Test)
    
function testCorrectConversionWithUncertainties(testCase)
% Generate random LFTs and check that they convert correctly
for i = 1:10
    if mod(i, 2)
        del_state = 'DeltaDelayZ';
        ts = -1;
    else
        del_state = 'DeltaIntegrator';
        ts = 0;
    end
    lft_r = Ulft.random('horizon_period', [0, 1],...
                        'req_deltas', {'DeltaDlti', 'DeltaSlti',del_state});
    uss_r = lftToRct(lft_r);
    [~, ~, uss_blk, ~] = lftdata(uss_r);
    
    % Check correctness of size
    verifyEqual(testCase, size(uss_r), [size(lft_r, 1), size(lft_r, 2)])
    num_deltas = length(lft_r.delta.deltas);
    
    % Check that names are preserved
    names = lft_r.delta.names;
    uss_names = fieldnames(uss_r.Uncertainty);
    names_match = cellfun(@(uname) any(strcmp(uname, names)), uss_names);
    verifyTrue(testCase, all(names_match))
    
    % Check that delta types and properties are converted, get samples
    del_sample = cell(1, num_deltas - 1);
    unc_sample = cell(1, num_deltas - 1);
    for j = 2:num_deltas
        del = lft_r.delta.deltas{j};
        unc = getfield(uss_r.Uncertainty, names{j});
        del_size = [del.dim_out, del.dim_in];
        switch class(del)
            case 'DeltaDlti'
                verifyEqual(testCase, class(unc), 'ultidyn')
                verifyEqual(testCase, unc.Bound, del.upper_bound)
                verifyEqual(testCase, size(unc), del_size)
            case 'DeltaSlti'
                verifyEqual(testCase, class(unc), 'ureal')
                del_range = [del.lower_bound, del.upper_bound];
                verifyEqual(testCase, unc.Range, del_range)
                unc_ind = find(strcmp(names{j}, uss_names), 1);
                unc_size = uss_blk(unc_ind).Occurrences;
                verifyEqual(testCase, unc_size, del_size(1))
            otherwise
                verifyEqual(testCase, class(unc), 'udyn')
                verifyEqual(testCase, size(unc), del_size)
        end
        
        if isa(del, 'DeltaSlti')
            unc_sample{j} = randn;
            del_sample{j} = toLft(unc_sample{j} * eye(del_size(1)));
        else
            if lft_r.timestep
                unc_sample{j} = drss(randi([1, 10]), del_size(1), del_size(2));
                unc_sample{j}.a = unc_sample{j}.a * 0.9;
                unc_sample{j}.Ts = lft_r.timestep;
            else
                unc_sample{j} = rss(randi([1, 10]), del_size(1), del_size(2));
                unc_sample{j}.a = unc_sample{j}.a -...
                                  0.1 * eye(size(unc_sample{j}.a, 1));
            end
            del_sample{j} = toLft(unc_sample{j});
        end
    end
    
    % Sample lfts and check equivalence
    lft_sam = sampleDeltas(lft_r, lft_r.delta.names(2:end), del_sample(2:end),...
                           'override', true);
    lft_sample = ss(lft_sam.a{1}, lft_sam.b{1}, lft_sam.c{1}, lft_sam.d{1}, ts);
    uss_sample = reshape([lft_r.delta.names; unc_sample], 1, 2 * num_deltas);
    uss_sample(1:2) = [];
    rct_sample = usubs(uss_r, uss_sample{:});
    sys_diff = norm(lft_sample - rct_sample, 'inf');
    tolerance = 1e-4 * norm(rct_sample, 'inf');
    verifyLessThan(testCase, sys_diff, tolerance)
end
end

function testCorrectConversionWithState(testCase)
% Generate LFTs with only DeltaDelayZ or DeltaIntegrator
    for i = 1:5
        if mod(i, 2)
            del_state = 'DeltaDelayZ';
            ts = -1;
        else
            del_state = 'DeltaIntegrator';
            ts = 0;
        end
        lft_r = Ulft.random('horizon_period', [0, 1],...
                            'num_deltas', 1,...
                            'req_deltas', {del_state});
        uss_r = lftToRct(lft_r);
        lft_r = ss(lft_r.a{1}, lft_r.b{1}, lft_r.c{1}, lft_r.d{1}, ts);

        % Check correctness of size and system
        verifyEqual(testCase, size(uss_r), [size(lft_r, 1), size(lft_r, 2)])
        sys_diff = norm(lft_r - uss_r, 'inf');
        verifyLessThan(testCase, sys_diff, 1e-4)
    end
end

function testCorrectConversionNoUncertainties(testCase)
% Generate LFTs without any Deltas
    for i = 1:5
        lft_r = Ulft.random('horizon_period', [0, 1], 'num_deltas', 0);
        uss_r = lftToRct(lft_r);
        % Check correctness of size and system
        verifyEqual(testCase, size(uss_r), [size(lft_r, 1), size(lft_r, 2)])
        verifyEqual(testCase, uss_r.d, lft_r.d{1})
    end
end

function testTimeVaryingErrorAndBadInput(testCase)
% Errors should be thrown when trying to convert time-varying LFTs
    horizon_period = [1, 1];
    lft_tv = toLft(DeltaDelayZ(1, -1, horizon_period));
    verifyError(testCase, @() lftToRct(lft_tv), 'lftToRct:lftToRct')
    verifyError(testCase, @() lftToRct('a'), 'MATLAB:invalidType')
    verifyError(testCase, @() lftToRct({1}), 'MATLAB:invalidType')
end

function testUdynMapping(testCase)
    num_del = 4;
    dim = randi([1, 5]);
    lb = -rand;
    ub = rand;
    del_sector = DeltaSectorBounded('sb', dim, lb, ub);
    req_dels = {'DeltaBounded', del_sector, 'DeltaSltvRateBnd'};
    lft_obj = Ulft.random('num_deltas', num_del,...
                          'req_deltas', req_dels,...
                          'horizon_period', [0, 1]);
    [rct_obj, del_map] = lftToRct(lft_obj);
    [~, ~, ~, delta_norm] = lftdata(rct_obj);
    for i = 1:length(delta_norm)
        name = erase(delta_norm{i}.Name, 'Normalized');
        del_ind = strcmp(lft_obj.delta.names, name);
        testCase.verifyEqual(del_map(name), lft_obj.delta.deltas{del_ind});
    end
    
end
end
    
end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0): Added after v0.5.0 - Micah Fry (micah.fry@ll.mit.edu)