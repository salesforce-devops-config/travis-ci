const os = require("os");

const prBody = process.argv[2]; // The first argument
const mode = process.argv[3]; // The second argument

const reSpecifiedTests = /\[CI TESTS\]((.|[\n\r])*?)\[\/CI TESTS\]/i;

const reNoTests = /\[NO CI TESTS\]/i;

const matches = prBody.match(reSpecifiedTests);
if (matches) {
    let testsToRun = matches[1]
        .replace(/\r\n/g, os.EOL)
        .split(os.EOL)
        .map(t => t.trim())
        .filter(m => m.length > 0);
    if (mode === 'runTests') {
        console.log(`--test-level RunSpecifiedTests --class-names ${testsToRun.join(',')}`);
    } else {
        console.log(`--test-level RunSpecifiedTests --tests ${testsToRun.join(' --tests ')}`);
    }
    return;
}

if (reNoTests.test(prBody)) {
    console.log('--test-level NoTestRun');
    return;
}

console.log('--test-level RunLocalTests');