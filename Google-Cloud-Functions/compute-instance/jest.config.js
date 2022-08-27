module.exports = {
    roots: ['../../build/Google-Cloud-Functions/compute-instance/test'],
    testMatch: [
        '**/__tests__/**/*.+(ts|tsx|js)',
        '**/?(*.)+(spec|test).+(ts|tsx|js)'
    ],
    testTimeout: 300000
};
