function [quatAverage quats] = testQuaternionAveraging()
n = 200000;
rotVecs = randn(n,3)+[1 0.5 -5];
quats = zeros(size(rotVecs,1), 4);
for i = 1:size(rotVecs, 1)
    quats(i,:) = axang2quat([rotVecs(i,:)/norm(rotVecs(i,:)) norm(rotVecs(i,:))]);
end

converged = false;
epsilons = ones(size(rotVecs,1),1);
while ~converged
    quatAverage = epsilons'*quats/norm(epsilons'*quats);
    sameEpsilon = sum((epsilons.*quats - quatAverage).^2,2);
    swapEpsilon = sum((-epsilons.*quats - quatAverage).^2,2);
    epsilons(swapEpsilon < sameEpsilon) = -epsilons(swapEpsilon < sameEpsilon);
    converged = ~any(swapEpsilon < sameEpsilon);
end
end