M = 64; % 64-QAM
N = 10000; % Number of symbols
EbNoVec = 0:2:20; % Eb/No range in dB
numSymErrors = 100; % Number of symbol errors to simulate for each Eb/No value
numIterations = 100; % Number of iterations for averaging SER

% Generate 64-QAM modulated symbols
data = randi([0 M-1], N, 1);
s = qammod(data, M, 'UnitAveragePower', true);

% Define impairment parameters
impairments = [
    0.8, 0,   0,   0;   % IQ Gain mismatch only
    1,   12,  0,   0;   % IQ Phase mismatch only
    1,   0,   0.5, 0.5; % DC offsets only
    0.8, 12,  0.5, 0.5; % IQ impairments & DC offsets
];

% Function to apply receiver impairments
apply_impairments = @(s, g, phi, dc_i, dc_q) ...
    g * (real(s) * cosd(phi) - imag(s) * sind(phi)) + 1i * (real(s) * sind(phi) + imag(s) * cosd(phi)) + dc_i + 1i * dc_q;

% Apply impairments
r_no_comp = apply_impairments(s, impairments(4, 1), impairments(4, 2), impairments(4, 3), impairments(4, 4));

% Define compensation methods (for simplicity, we assume perfect compensation)
dc_compensation = @(r) r - mean(real(r)) - 1i * mean(imag(r));
iq_compensation = @(r, g, phi) ...
    (real(r) / g * cosd(phi) + imag(r) / g * sind(phi)) + 1i * (-real(r) / g * sind(phi) + imag(r) / g * cosd(phi));

% Placeholder for SER results
ser_no_comp = zeros(size(EbNoVec));
ser_dc_comp = zeros(size(EbNoVec));
ser_iq_comp = zeros(size(EbNoVec));

% Simulate transmission over AWGN channel for different Eb/No values
for idx = 1:length(EbNoVec)
    EbNo = EbNoVec(idx);
    snr = EbNo + 10*log10(log2(M)); % Convert Eb/No to SNR
    ser_no_comp_sum = 0;
    ser_dc_comp_sum = 0;
    ser_iq_comp_sum = 0;
   
    for iter = 1:numIterations
        % Add AWGN noise
        r_noisy = awgn(r_no_comp, snr, 'measured');
       
        % Apply no compensation
        demod_no_comp = qamdemod(r_noisy, M, 'UnitAveragePower', true);
        ser_no_comp_sum = ser_no_comp_sum + sum(demod_no_comp ~= data) / N;
       
        % Apply DC compensation
        r_dc_comp = dc_compensation(r_noisy);
        demod_dc_comp = qamdemod(r_dc_comp, M, 'UnitAveragePower', true);
        ser_dc_comp_sum = ser_dc_comp_sum + sum(demod_dc_comp ~= data) / N;
       
        % Apply IQ compensation
        r_iq_comp = iq_compensation(r_dc_comp, impairments(4, 1), impairments(4, 2));
        demod_iq_comp = qamdemod(r_iq_comp, M, 'UnitAveragePower', true);
        ser_iq_comp_sum = ser_iq_comp_sum + sum(demod_iq_comp ~= data) / N;
    end
   
    % Average SER over iterations
    ser_no_comp(idx) = ser_no_comp_sum / numIterations;
    ser_dc_comp(idx) = ser_dc_comp_sum / numIterations;
    ser_iq_comp(idx) = ser_iq_comp_sum / numIterations;
end

% Plot the results
figure;
semilogy(EbNoVec, ser_no_comp, 'r-o', 'DisplayName', 'No Compensation');
hold on;
semilogy(EbNoVec, ser_dc_comp, 'g-*', 'DisplayName', 'DC Compensation Only');
semilogy(EbNoVec, ser_iq_comp, 'b-s', 'DisplayName', 'DC + IQ Compensation');
xlabel('E_b/N_0 (dB)');
ylabel('Symbol Error Rate (SER)');
title('64-QAM Performance with Receiver Impairments');
legend;
grid on;
hold off;