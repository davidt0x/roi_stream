classdef lsrCtrlParams
  
  
  properties
    
    
    % laser waveform
    pulseIntervalDur= 10;       % time between pulses, sec
    numpulses       = 10;       % number of times to stimulate each region
    dutyCycle       = .005;     % how long is laser on during each pulse, sec

    % galvo calibration
    slopex                      % slope of vertical pixel location vs. galvo Vx relationship
    slopey                      % slope of horizontal pixel location vs. galvo Vy relationship
    intx                        % intercept of vertical pixel location vs. galvo Vx relationship
    inty                        % intercept of horizontal pixel location vs. galvo Vy relationship
    data                        % cell array of snapshots at every grid point during calibration
    GalvoVoltage                % cell array of galvo voltages at every grid point during calibration
    
    % experiment control
    outputs        = zeros(1,4);% output data for laser and galvo communication
    grid                        % to store fiber indices and locations
    galvo_grid                  % to store galvo voltages corresponding to each location in `grid`
    cycleCounter   = 0;         % cycles completed
    stop           = 1;         % stop laser stim loop
    loopType       = 'ordered'; % how to select regions, either 'ordered' or 'random'
    time_start_vid
    mids

    
  end
end