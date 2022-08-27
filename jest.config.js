module.exports = {
    roots: ['<rootDir>/build'],
    testMatch: [
        '**/__tests__/**/*.+(ts|tsx|js)',
        '**/?(*.)+(spec|test).+(ts|tsx|js)'
    ],
    testTimeout: 300000
};
