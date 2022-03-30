%% Requirements:
%  1. DeltaConstantDelay shall be defined by it's name, the input/output
%      dimension, the maximum allowable delay, and the
%      horizon_period
%  2. Upon construction, and when queried by user, it shall display the
%      information described in (1).
%
%  3. If input/output dimenstion is not provided by the user, by
%      default the in/out dimension shall be 1, the maximum delay shall be 1, 
%      and the horizon_period shall be [0, 1].
%
%  4. If the user provides no name, DeltaConstantDelay shall throw an 
%      exception
%
%  5. DeltaConstantDelay shall ensure that it's properties are consistent 
%      with its current horizon_period property
%  6. DeltaConstantDelay shall be capable of changing it's properties to 
%      match a newly input horizon_period, as long as the new 
%      horizon_period is consistent with the prior horizon_period
%
%  7. DeltaConstantDelay shall be capable of generating a
%       MultiplierConstantDelay from a DeltaConstantDelay object

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for DeltaConstantDelay and MultiplierConstantDelay
classdef testDeltaConstantDelay < matlab.unittest.TestCase
    
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
    
methods (Test)
function testFullConstructor(testCase)
    name = 'test';
    dim_outin = randi([1, 10]);
    delay_max = randi([1, 10]);
    horizon_period = [randi([0, 10]), randi([1, 10])];
    d = DeltaConstantDelay(name, dim_outin, delay_max, horizon_period)
    total_time = sum(horizon_period);
    testCase.verifyEqual(d.name, name)
    testCase.verifyEqual(d.dim_out, repmat(dim_outin, 1, total_time))
    testCase.verifyEqual(d.dim_in,  repmat(dim_outin, 1, total_time))
    testCase.verifyEqual(d.delay_max, repmat(delay_max, 1, total_time))
    testCase.verifyEqual(d.horizon_period, horizon_period)
end

function testThreeArgConstructor(testCase)
    name = 'test';
    dim_outin = randi([1, 10]);
    delay_max = randi([1, 10]);
    d = DeltaConstantDelay(name, dim_outin, delay_max);
    testCase.verifyEqual(d.name, name)
    testCase.verifyEqual(d.dim_out, dim_outin)
    testCase.verifyEqual(d.dim_in,  dim_outin)
    testCase.verifyEqual(d.delay_max, delay_max)
    testCase.verifyEqual(d.horizon_period, [0, 1])
end

function testTwoArgConstructor(testCase)
    name = 'test';
    dim_outin = randi([1, 10]);
    d = DeltaConstantDelay(name, dim_outin);
    testCase.verifyEqual(d.name, name)
    testCase.verifyEqual(d.dim_out, dim_outin)
    testCase.verifyEqual(d.dim_in,  dim_outin)
    testCase.verifyEqual(d.delay_max, 1)
    testCase.verifyEqual(d.horizon_period, [0, 1])
end

function testOneArgConstructor(testCase)
    name = 'test';
    d = DeltaConstantDelay(name);
    testCase.verifyEqual(d.name, name)
    testCase.verifyEqual(d.dim_out, 1)
    testCase.verifyEqual(d.dim_in,  1)
    testCase.verifyEqual(d.delay_max, 1)
    testCase.verifyEqual(d.horizon_period, [0, 1])
end

function testSamplingDelta(testCase)
    dim_outin = randi([1, 10]);
    delay_max = randi([1, 10]);
    d = DeltaConstantDelay('test', dim_outin, delay_max);
    timestep = -1;
    d.validateSample(d.sample(timestep), timestep)
end

function testBadConstructorCalls(testCase)
    testCase.verifyError(@() DeltaConstantDelay(),...
                         'DeltaConstantDelay:DeltaConstantDelay')
end

function testMultiplierConstruction(testCase)
    name = 'test';
    del = DeltaConstantDelay(name);
    m = MultiplierConstantDelay(del);
    testCase.verifyTrue(m.constraint_q11_kyp)

    constraint_q11_kyp = false;
    m = MultiplierConstantDelay(del, 'constraint_q11_kyp', constraint_q11_kyp);
    testCase.verifyEqual(m.constraint_q11_kyp, constraint_q11_kyp)
end

function testDefaultConstructor(testCase)
    d = DeltaConstantDelay('test');
    m = MultiplierConstantDelay(d);

    % Standard property check
    verifyEqual(testCase, m.name,           d.name);
    verifyEqual(testCase, m.horizon_period, d.horizon_period)
    verifyEqual(testCase, m.delay_max,      d.delay_max);
    verifyEqual(testCase, m.dim_outin,      d.dim_out);

    % Check defaults
    verifyTrue(testCase, m.discrete)
    verifyTrue(testCase, m.constraint_q11_kyp)
    verifyEqual(testCase, m.basis_length, 2)
    verifyEqual(testCase, m.basis_poles, -0.5)
    verifyEqual(testCase, size(m.basis_function), [m.basis_length, 1])
    verifyEqual(testCase, size(m.basis_realization), [m.basis_length, 1])
    [~, U] = minreal(m.basis_realization);
    verifyEqual(testCase, U, eye(size(U, 1)));
    verifyEqual(testCase,...
                size(m.block_realization),...
                [m.basis_length * m.dim_outin, m.dim_outin])
end

function testNoPoles(testCase)
    del = DeltaConstantDelay('test');
    basis_length = 1;
    mult = MultiplierConstantDelay(del, 'basis_length', basis_length);
    verifyEqual(testCase, mult.basis_length, basis_length)
    verifyEmpty(testCase, mult.basis_poles)
    
    basis_poles = [];
    mult = MultiplierConstantDelay(del, 'basis_poles', basis_poles);
    verifyEqual(testCase, mult.basis_length, basis_length)
    verifyEmpty(testCase, mult.basis_poles)
end

function testLongBasisOneRealPole(testCase)
    del = DeltaConstantDelay('test');
    basis_length = 5;
    basis_poles = 0.6;
    mult = MultiplierConstantDelay(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    basis_function_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(basis_function_zpk.P{i}' - ...
                           repmat(basis_poles, 1, i - 1)),...
                       1e-4 * ones(i - 1, 1))                               
    end            
end

function testLongBasisManyRealPoles(testCase)
    del = DeltaConstantDelay('test');
    basis_length = 5;
    basis_poles = linspace(-.9, .9, basis_length - 1)';
    mult = MultiplierConstantDelay(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    bf_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(bf_zpk.P{i} - basis_poles(i - 1)), 1e-4)                               
    end            
end

function testLongBasisOneComplexPairPoles(testCase)
    del = DeltaConstantDelay('test');
    basis_length = 5;
    basis_poles = [.5 + .5i, .5 - .5i];
    mult = MultiplierConstantDelay(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    bf_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(cplxpair(bf_zpk.P{i}') - ...
                           cplxpair(repmat(basis_poles, 1, i - 1))),...
                       1e-3 * ones(i - 1, 1))                             
    end            
end

function testBasisPoleErrors(testCase)
    del = DeltaConstantDelay('test');
    basis_length = 3;
    basis_poles = linspace(-.3,-.1,basis_length)';
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for too many poles',...
                 'given the length (real poles, in discrete-time)'])

    basis_length = 5;
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for too few poles',...
                 'given the length (real poles, in continuous-time)'])

    basis_length = 2;
    basis_poles = -1.2;
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(real poles, in discrete-time)'])

    basis_poles = 1.2;
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(real poles, in continuous-time)'])

    basis_poles = [-.5 + 1.2i, -.5 - 1.2i];
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(complex poles, in discrete-time)'])

    basis_poles = [1.2i, -1.2i];
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(complex poles, in continuous-time)'])

    basis_poles = [.5i, -.4i];
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for non-conjugate',...
                 'pole pairs (in discrete-time)'])

    basis_poles = [-2 + .5i, -2 - .4i];
    verifyError(testCase, ...
                @() MultiplierConstantDelay(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for non-conjugate',...
                 'pole pairs (in continuous-time)'])

end

function testSetBasisFunction(testCase)
    del = DeltaConstantDelay('test');
    rng(10, 'twister')
    basis_ss = rss(4, 6, 1);
    basis_function = tf(basis_ss);
    while (~isstable(basis_function))
        basis_ss = rss(4, 6, 1);
        basis_function = tf(basis_ss);
    end            
    mult = MultiplierConstantDelay(del,...
              'basis_function', basis_function,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_function, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_function, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEqual(testCase, mult.basis_function, basis_function)
    diff_norm = norm(lftToSs(mult.filter_lft) - blkdiag(basis_ss, basis_ss),...
                     'inf');
    verifyLessThan(testCase, diff_norm, 1e-3)

    basis_ss = drss(4, 6, 1);
    basis_function = tf(basis_ss);
    while (~isstable(basis_function))
        basis_ss = drss(4, 6, 1);
        basis_function = tf(basis_ss);
    end            
    mult = MultiplierConstantDelay(del,...
              'basis_function', basis_function);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_function, ',...
                 'basis_length should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_function, ',...
                 'basis_poles should set empty (discrete-time)']);
    verifyEqual(testCase, mult.basis_function, basis_function)
    diff_norm = norm(lftToSs(mult.filter_lft) - blkdiag(basis_ss, basis_ss),...
                     'inf');
    verifyLessThan(testCase, diff_norm, 1e-3)
end

function testBasisFunctionErrors(testCase)
    del = DeltaConstantDelay('test');

    basis_function = tf(zpk([], 0.5, 1));
    verifyError(testCase,...
                @() MultiplierConstantDelay(del,...
                                   'basis_function', basis_function,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_function (continuous-time)'])

    basis_function = tf(zpk([], -1.1, 1, []));
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_function (discrete-time)'])

    basis_function = tf(drss(randi(4), randi(4), 2));
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing a tf',...
                 'whose width is greater than 1'])

    basis_function = tf(drss(1));
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_function', basis_function,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    basis_function = tf(rss(1));
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                     
end

function testSetBasisRealization(testCase)
    del = DeltaConstantDelay('test');

    basis_realization = rss(4, 6, 1);
    while (~isstable(basis_realization))
        basis_realization = rss(4, 6, 1);
    end            
    mult = MultiplierConstantDelay(del,...
              'basis_realization', basis_realization,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting basis_realization, ',...
                 'basis_function should set empty (continuous-time)']);

    verifyEqual(testCase, mult.basis_realization, basis_realization)

    basis_realization = drss(4, 6, 1);
    while (~isstable(basis_realization))
        basis_realization = drss(4, 6, 1);
    end            
    mult = MultiplierConstantDelay(del,...
              'basis_realization', basis_realization);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_realization, ',...
                 'basis_length should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_realization, ',...
                 'basis_poles should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting basis_realization, ',...
                 'basis_function should set empty (discrete-time)']);

    verifyEqual(testCase, mult.basis_realization, basis_realization)
end        

function testBasisRealizationErrors(testCase)
    del = DeltaConstantDelay('test');

    br = ss(0.5, 1, 1, 0);
    verifyError(testCase,...
                @() MultiplierConstantDelay(del,...
                                   'basis_realization', br,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_realization (continuous-time)'])

    br = ss(-1.2, 1, 1, 0, []);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_realization (discrete-time)'])

    br = drss(randi(4), randi(4), 2);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a tf',...
                 'whose width is greater than 1'])

    br = drss(1);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_realization', br,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    br = rss(1);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                      
end        

function testSetBlockRealization(testCase)
    dim_del = 3;
    del = DeltaConstantDelay('test',dim_del);

    block_realization = drss(4, 6, dim_del);
    while (~isstable(block_realization))
        block_realization = drss(4, 6, dim_del);
    end            
    mult = MultiplierConstantDelay(del,...
              'block_realization', block_realization);
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting block_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting block_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting block_realization, ',...
                 'basis_function should set empty (continuous-time)'])
    verifyEmpty(testCase,...
                mult.basis_realization,...
                ['When independently setting block_realization, ',...
                 'basis_realization should set empty (continuous-time)'])

    verifyEqual(testCase, mult.block_realization, block_realization)

    block_realization = rss(4, 6, dim_del);
    while (~isstable(block_realization))
        block_realization = rss(4, 6, dim_del);
    end            
    mult = MultiplierConstantDelay(del,...
              'block_realization', block_realization,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting block_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting block_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting block_realization, ',...
                 'basis_function should set empty (continuous-time)'])
    verifyEmpty(testCase,...
                mult.basis_realization,...
                ['When independently setting block_realization, ',...
                 'basis_realization should set empty (continuous-time)'])

    verifyEqual(testCase, mult.block_realization, block_realization)            

end        

function testBlockRealizationErrors(testCase)
    del = DeltaConstantDelay('test');

    br = ss(0.5, 1, 1, 0);
    verifyError(testCase,...
                @() MultiplierConstantDelay(del,...
                                   'block_realization', br,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable block_realization (continuous-time)'])

    br = ss(-1.2, 1, 1, 0, []);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'block_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable block_realization (discrete-time)'])

    br = drss(1);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'block_realization', br,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    br = rss(1);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'block_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                      

    del = DeltaConstantDelay('test', 3);
    br = drss(randi(4), randi(4), 4);
    verifyError(testCase,...
                @()MultiplierConstantDelay(del,...
                                  'block_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a tf',...
                 'whose width is greater than delta.dim_out'])                     
end       




end
end

%%  CHANGELOG
% Mar. 30, 2022: Added after v0.9.0 - Micah Fry (micah.fry@ll.mit.edu)