#!/usr/bin/env node

/**
 * BitFlow Test Report Generator
 * Aggregates test results from all test suites and generates comprehensive reports
 */

const fs = require('fs');
const path = require('path');

class TestReportGenerator {
    constructor() {
        this.testArtifactsDir = 'test-artifacts';
        this.reportDir = 'test-reports';
        this.coverageDir = 'coverage';
        
        // Ensure directories exist
        this.ensureDirectories();
    }

    ensureDirectories() {
        [this.reportDir, this.coverageDir].forEach(dir => {
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
        });
    }

    parseTestResults() {
        const results = {
            unit: this.parseUnitTests(),
            userJourney: this.parseUserJourneyTests(),
            crossChain: this.parseCrossChainTests(),
            performance: this.parsePerformanceTests(),
            load: this.parseLoadTests()
        };

        return results;
    }

    parseUnitTests() {
        return this.parseTestSuite('unit-test-results', 'Unit Tests');
    }

    parseUserJourneyTests() {
        return this.parseTestSuite('user-journey-test-results', 'User Journey Tests');
    }

    parseCrossChainTests() {
        return this.parseTestSuite('cross-chain-test-results', 'Cross-Chain Tests');
    }

    parsePerformanceTests() {
        return this.parseTestSuite('performance-test-results', 'Performance Tests');
    }

    parseLoadTests() {
        return this.parseTestSuite('load-test-results', 'Load Tests');
    }

    parseTestSuite(artifactName, suiteName) {
        const artifactPath = path.join(this.testArtifactsDir, artifactName);
        
        // Default result structure
        const result = {
            name: suiteName,
            status: 'UNKNOWN',
            passed: 0,
            failed: 0,
            total: 0,
            duration: 0,
            successRate: 0,
            coverage: 0,
            details: []
        };

        if (!fs.existsSync(artifactPath)) {
            console.warn(`Artifact not found: ${artifactPath}`);
            result.status = 'NOT_RUN';
            return result;
        }

        try {
            // Look for test result files
            const files = fs.readdirSync(artifactPath, { recursive: true });
            
            // Parse coverage files if available
            const coverageFiles = files.filter(f => f.includes('coverage') || f.endsWith('.lcov'));
            if (coverageFiles.length > 0) {
                result.coverage = this.parseCoverageFile(path.join(artifactPath, coverageFiles[0]));
            }

            // Parse test output files
            const logFiles = files.filter(f => f.endsWith('.log') || f.endsWith('.json'));
            for (const logFile of logFiles) {
                const logPath = path.join(artifactPath, logFile);
                const logContent = fs.readFileSync(logPath, 'utf8');
                
                // Parse test results from log content
                const testResults = this.parseLogContent(logContent);
                result.passed += testResults.passed;
                result.failed += testResults.failed;
                result.duration += testResults.duration;
                result.details.push(...testResults.details);
            }

            result.total = result.passed + result.failed;
            result.successRate = result.total > 0 ? Math.round((result.passed / result.total) * 100) : 0;
            result.status = result.failed === 0 ? 'PASSED' : 'FAILED';

        } catch (error) {
            console.error(`Error parsing test suite ${suiteName}:`, error);
            result.status = 'ERROR';
        }

        return result;
    }

    parseLogContent(content) {
        const result = {
            passed: 0,
            failed: 0,
            duration: 0,
            details: []
        };

        // Parse snforge output format
        const lines = content.split('\n');
        
        for (const line of lines) {
            // Look for test result patterns
            if (line.includes('test result:')) {
                const match = line.match(/(\d+) passed.*?(\d+) failed.*?(\d+\.\d+)s/);
                if (match) {
                    result.passed += parseInt(match[1]);
                    result.failed += parseInt(match[2]);
                    result.duration += parseFloat(match[3]);
                }
            }
            
            // Look for individual test results
            if (line.includes('test ') && (line.includes('... ok') || line.includes('... FAILED'))) {
                const testName = line.match(/test (.*?) \.\.\./)?.[1];
                const status = line.includes('... ok') ? 'PASSED' : 'FAILED';
                
                if (testName) {
                    result.details.push({
                        name: testName,
                        status: status,
                        duration: 0 // Individual test duration not always available
                    });
                }
            }
        }

        return result;
    }

    parseCoverageFile(filePath) {
        try {
            const content = fs.readFileSync(filePath, 'utf8');
            
            // Parse LCOV format
            if (filePath.endsWith('.lcov')) {
                const lines = content.split('\n');
                let totalLines = 0;
                let coveredLines = 0;
                
                for (const line of lines) {
                    if (line.startsWith('LF:')) {
                        totalLines += parseInt(line.split(':')[1]);
                    } else if (line.startsWith('LH:')) {
                        coveredLines += parseInt(line.split(':')[1]);
                    }
                }
                
                return totalLines > 0 ? Math.round((coveredLines / totalLines) * 100) : 0;
            }
            
            // Parse JSON coverage format
            try {
                const coverageData = JSON.parse(content);
                // Extract coverage percentage from JSON structure
                // This would depend on the specific format used by snforge
                return 0; // Placeholder
            } catch {
                return 0;
            }
            
        } catch (error) {
            console.warn(`Could not parse coverage file ${filePath}:`, error.message);
            return 0;
        }
    }

    generateSummaryReport(results) {
        const summary = {
            timestamp: new Date().toISOString(),
            overall: {
                totalTests: 0,
                totalPassed: 0,
                totalFailed: 0,
                totalDuration: 0,
                successRate: 0,
                averageCoverage: 0
            },
            suites: results
        };

        // Calculate overall metrics
        for (const suite of Object.values(results)) {
            summary.overall.totalTests += suite.total;
            summary.overall.totalPassed += suite.passed;
            summary.overall.totalFailed += suite.failed;
            summary.overall.totalDuration += suite.duration;
        }

        const suiteCount = Object.keys(results).length;
        summary.overall.successRate = summary.overall.totalTests > 0 
            ? Math.round((summary.overall.totalPassed / summary.overall.totalTests) * 100) 
            : 0;
        
        summary.overall.averageCoverage = suiteCount > 0 
            ? Math.round(Object.values(results).reduce((sum, suite) => sum + suite.coverage, 0) / suiteCount)
            : 0;

        return summary;
    }

    generateHTMLReport(summary) {
        const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BitFlow E2E Test Report</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .metric {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric h3 {
            margin: 0 0 10px 0;
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .metric .value {
            font-size: 2em;
            font-weight: bold;
            color: #333;
        }
        .metric.success .value { color: #28a745; }
        .metric.warning .value { color: #ffc107; }
        .metric.danger .value { color: #dc3545; }
        .suites {
            padding: 30px;
        }
        .suite {
            margin-bottom: 30px;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            overflow: hidden;
        }
        .suite-header {
            padding: 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #e9ecef;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .suite-title {
            font-size: 1.2em;
            font-weight: bold;
            color: #333;
        }
        .suite-status {
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            text-transform: uppercase;
        }
        .suite-status.passed {
            background: #d4edda;
            color: #155724;
        }
        .suite-status.failed {
            background: #f8d7da;
            color: #721c24;
        }
        .suite-status.unknown {
            background: #e2e3e5;
            color: #383d41;
        }
        .suite-details {
            padding: 20px;
        }
        .suite-metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .suite-metric {
            text-align: center;
        }
        .suite-metric .label {
            font-size: 0.8em;
            color: #666;
            margin-bottom: 5px;
        }
        .suite-metric .value {
            font-size: 1.5em;
            font-weight: bold;
            color: #333;
        }
        .test-details {
            margin-top: 20px;
        }
        .test-item {
            padding: 10px;
            border-left: 4px solid #e9ecef;
            margin-bottom: 5px;
            background: #f8f9fa;
        }
        .test-item.passed {
            border-left-color: #28a745;
        }
        .test-item.failed {
            border-left-color: #dc3545;
        }
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            border-top: 1px solid #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>BitFlow Protocol</h1>
            <p>End-to-End Test Report - ${new Date(summary.timestamp).toLocaleString()}</p>
        </div>
        
        <div class="metrics">
            <div class="metric ${summary.overall.successRate >= 95 ? 'success' : summary.overall.successRate >= 80 ? 'warning' : 'danger'}">
                <h3>Success Rate</h3>
                <div class="value">${summary.overall.successRate}%</div>
            </div>
            <div class="metric">
                <h3>Total Tests</h3>
                <div class="value">${summary.overall.totalTests}</div>
            </div>
            <div class="metric success">
                <h3>Passed</h3>
                <div class="value">${summary.overall.totalPassed}</div>
            </div>
            <div class="metric ${summary.overall.totalFailed > 0 ? 'danger' : 'success'}">
                <h3>Failed</h3>
                <div class="value">${summary.overall.totalFailed}</div>
            </div>
            <div class="metric">
                <h3>Duration</h3>
                <div class="value">${Math.round(summary.overall.totalDuration)}s</div>
            </div>
            <div class="metric ${summary.overall.averageCoverage >= 80 ? 'success' : summary.overall.averageCoverage >= 60 ? 'warning' : 'danger'}">
                <h3>Coverage</h3>
                <div class="value">${summary.overall.averageCoverage}%</div>
            </div>
        </div>
        
        <div class="suites">
            <h2>Test Suites</h2>
            ${Object.values(summary.suites).map(suite => `
                <div class="suite">
                    <div class="suite-header">
                        <div class="suite-title">${suite.name}</div>
                        <div class="suite-status ${suite.status.toLowerCase()}">${suite.status}</div>
                    </div>
                    <div class="suite-details">
                        <div class="suite-metrics">
                            <div class="suite-metric">
                                <div class="label">Tests</div>
                                <div class="value">${suite.total}</div>
                            </div>
                            <div class="suite-metric">
                                <div class="label">Passed</div>
                                <div class="value">${suite.passed}</div>
                            </div>
                            <div class="suite-metric">
                                <div class="label">Failed</div>
                                <div class="value">${suite.failed}</div>
                            </div>
                            <div class="suite-metric">
                                <div class="label">Duration</div>
                                <div class="value">${Math.round(suite.duration)}s</div>
                            </div>
                            <div class="suite-metric">
                                <div class="label">Coverage</div>
                                <div class="value">${suite.coverage}%</div>
                            </div>
                        </div>
                        ${suite.details.length > 0 ? `
                            <div class="test-details">
                                <h4>Test Details</h4>
                                ${suite.details.map(test => `
                                    <div class="test-item ${test.status.toLowerCase()}">
                                        ${test.name} - ${test.status}
                                    </div>
                                `).join('')}
                            </div>
                        ` : ''}
                    </div>
                </div>
            `).join('')}
        </div>
        
        <div class="footer">
            <p>Generated by BitFlow E2E Testing Suite</p>
            <p>${summary.overall.successRate >= 95 ? '✅ Ready for deployment!' : '❌ Not ready for deployment'}</p>
        </div>
    </div>
</body>
</html>`;

        return html;
    }

    generateJSONReport(summary) {
        return JSON.stringify(summary, null, 2);
    }

    run() {
        console.log('🧪 Generating BitFlow E2E Test Report...');
        
        try {
            // Parse all test results
            const results = this.parseTestResults();
            
            // Generate summary
            const summary = this.generateSummaryReport(results);
            
            // Write JSON report
            const jsonReport = this.generateJSONReport(summary);
            fs.writeFileSync(path.join(this.reportDir, 'summary.json'), jsonReport);
            
            // Write HTML report
            const htmlReport = this.generateHTMLReport(summary);
            fs.writeFileSync(path.join(this.reportDir, 'index.html'), htmlReport);
            
            // Write simplified summary for CI
            const ciSummary = {
                unit: { status: results.unit.status, passed: results.unit.passed, failed: results.unit.failed, duration: results.unit.duration },
                userJourney: { status: results.userJourney.status, passed: results.userJourney.passed, failed: results.userJourney.failed, duration: results.userJourney.duration },
                crossChain: { status: results.crossChain.status, passed: results.crossChain.passed, failed: results.crossChain.failed, duration: results.crossChain.duration },
                performance: { status: results.performance.status, passed: results.performance.passed, failed: results.performance.failed, duration: results.performance.duration },
                load: { status: results.load.status, passed: results.load.passed, failed: results.load.failed, duration: results.load.duration },
                overall: summary.overall
            };
            fs.writeFileSync(path.join(this.reportDir, 'ci-summary.json'), JSON.stringify(ciSummary, null, 2));
            
            console.log('✅ Test report generated successfully!');
            console.log(`📊 Overall Success Rate: ${summary.overall.successRate}%`);
            console.log(`📈 Total Tests: ${summary.overall.totalTests} (${summary.overall.totalPassed} passed, ${summary.overall.totalFailed} failed)`);
            console.log(`⏱️  Total Duration: ${Math.round(summary.overall.totalDuration)}s`);
            console.log(`📋 Reports saved to: ${this.reportDir}/`);
            
            // Exit with appropriate code
            process.exit(summary.overall.totalFailed > 0 ? 1 : 0);
            
        } catch (error) {
            console.error('❌ Error generating test report:', error);
            process.exit(1);
        }
    }
}

// Run the report generator
if (require.main === module) {
    const generator = new TestReportGenerator();
    generator.run();
}

module.exports = TestReportGenerator;