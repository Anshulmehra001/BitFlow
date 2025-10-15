// Security test data and attack vectors for BitFlow protocol testing

use starknet::{ContractAddress, contract_address_const};

// Common attack vectors and malicious payloads
#[generate_trait]
impl SecurityTestDataImpl of SecurityTestDataTrait {
    // SQL Injection payloads
    fn get_sql_injection_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('\' OR \'1\'=\'1');
        payloads.append('\' UNION SELECT * FROM users--');
        payloads.append('\'; DROP TABLE streams;--');
        payloads.append('\' OR 1=1#');
        payloads.append('\' AND (SELECT COUNT(*) FROM users) > 0--');
        payloads
    }

    // Cross-Site Scripting (XSS) payloads
    fn get_xss_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('<script>alert(\'XSS\')</script>');
        payloads.append('javascript:alert(\'XSS\')');
        payloads.append('<img src=x onerror=alert(\'XSS\')>');
        payloads.append('<svg onload=alert(\'XSS\')>');
        payloads.append('"><script>alert(\'XSS\')</script>');
        payloads
    }

    // Command injection payloads
    fn get_command_injection_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('; ls -la');
        payloads.append('| cat /etc/passwd');
        payloads.append('&& rm -rf /');
        payloads.append('`whoami`');
        payloads.append('$(id)');
        payloads
    }

    // Path traversal payloads
    fn get_path_traversal_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('../../../etc/passwd');
        payloads.append('..\\..\\..\\windows\\system32\\config\\sam');
        payloads.append('....//....//....//etc/passwd');
        payloads.append('%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd');
        payloads.append('..%252f..%252f..%252fetc%252fpasswd');
        payloads
    }

    // LDAP injection payloads
    fn get_ldap_injection_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('*)(uid=*))(|(uid=*');
        payloads.append('admin)(&(password=*))');
        payloads.append('*)(|(password=*))');
        payloads.append('admin))(|(|');
        payloads.append('*))%00');
        payloads
    }

    // NoSQL injection payloads
    fn get_nosql_injection_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('{"$ne": null}');
        payloads.append('{"$gt": ""}');
        payloads.append('{"$regex": ".*"}');
        payloads.append('{"$where": "this.password.length > 0"}');
        payloads.append('{"$or": [{"password": {"$ne": null}}, {"password": {"$exists": true}}]}');
        payloads
    }

    // Buffer overflow payloads
    fn get_buffer_overflow_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        // These would be very long strings in practice
        payloads.append('A' * 1000);
        payloads.append('A' * 5000);
        payloads.append('A' * 10000);
        payloads.append('\x41' * 1000);
        payloads.append('%41' * 1000);
        payloads
    }

    // Format string attack payloads
    fn get_format_string_payloads() -> Array<felt252> {
        let mut payloads = ArrayTrait::new();
        payloads.append('%x%x%x%x');
        payloads.append('%s%s%s%s');
        payloads.append('%n%n%n%n');
        payloads.append('%08x.%08x.%08x');
        payloads.append('%d%d%d%d%d%d%d%d%d%d');
        payloads
    }

    // Integer overflow test values
    fn get_integer_overflow_values() -> Array<u256> {
        let mut values = ArrayTrait::new();
        values.append(0xffffffffffffffffffffffffffffffff); // Max u256
        values.append(0xfffffffffffffffffffffffffffffffe); // Max - 1
        values.append(0x8000000000000000000000000000000); // Large value
        values.append(0); // Zero
        values.append(1); // One
        values
    }

    // Malicious contract addresses for testing
    fn get_malicious_addresses() -> Array<ContractAddress> {
        let mut addresses = ArrayTrait::new();
        addresses.append(contract_address_const::<0>()); // Zero address
        addresses.append(contract_address_const::<0x1>()); // Minimal address
        addresses.append(contract_address_const::<0xffffffffffffffffffffffffffffffff>()); // Max address
        addresses.append(contract_address_const::<'malicious_contract'>());
        addresses.append(contract_address_const::<'reentrancy_attacker'>());
        addresses
    }

    // Timing attack test data
    fn get_timing_attack_scenarios() -> Array<TimingAttackScenario> {
        let mut scenarios = ArrayTrait::new();
        
        scenarios.append(TimingAttackScenario {
            operation: 'password_verification',
            correct_input: 'correct_password',
            incorrect_inputs: array!['wrong_pass', 'incorrect', 'bad_password'],
            expected_timing_difference: 0, // Should be constant time
        });
        
        scenarios.append(TimingAttackScenario {
            operation: 'signature_verification',
            correct_input: 'valid_signature',
            incorrect_inputs: array!['invalid_sig', 'wrong_signature', 'bad_sig'],
            expected_timing_difference: 0,
        });
        
        scenarios
    }

    // Race condition test scenarios
    fn get_race_condition_scenarios() -> Array<RaceConditionScenario> {
        let mut scenarios = ArrayTrait::new();
        
        scenarios.append(RaceConditionScenario {
            operation: 'double_spending',
            concurrent_operations: 2,
            expected_success_count: 1,
            resource_type: 'stream_balance',
        });
        
        scenarios.append(RaceConditionScenario {
            operation: 'withdrawal_race',
            concurrent_operations: 5,
            expected_success_count: 1,
            resource_type: 'stream_funds',
        });
        
        scenarios
    }

    // Cryptographic attack test data
    fn get_crypto_attack_vectors() -> Array<CryptoAttackVector> {
        let mut vectors = ArrayTrait::new();
        
        vectors.append(CryptoAttackVector {
            attack_type: 'weak_randomness',
            target: 'stream_id_generation',
            payload: array!['predictable_seed', 'timestamp_based'],
            expected_vulnerability: false,
        });
        
        vectors.append(CryptoAttackVector {
            attack_type: 'signature_malleability',
            target: 'transaction_signatures',
            payload: array!['modified_signature', 'flipped_bits'],
            expected_vulnerability: false,
        });
        
        vectors
    }

    // Business logic attack scenarios
    fn get_business_logic_attacks() -> Array<BusinessLogicAttack> {
        let mut attacks = ArrayTrait::new();
        
        attacks.append(BusinessLogicAttack {
            attack_name: 'negative_amount_stream',
            target_function: 'create_stream',
            malicious_parameters: array!['-1000000', '0', 'negative_rate'],
            expected_result: 'rejection',
        });
        
        attacks.append(BusinessLogicAttack {
            attack_name: 'zero_duration_stream',
            target_function: 'create_stream',
            malicious_parameters: array!['1000000', '1000', '0'],
            expected_result: 'rejection',
        });
        
        attacks.append(BusinessLogicAttack {
            attack_name: 'self_stream_creation',
            target_function: 'create_stream',
            malicious_parameters: array!['same_address_as_sender'],
            expected_result: 'rejection',
        });
        
        attacks
    }

    // Denial of Service attack vectors
    fn get_dos_attack_vectors() -> Array<DoSAttackVector> {
        let mut vectors = ArrayTrait::new();
        
        vectors.append(DoSAttackVector {
            attack_type: 'resource_exhaustion',
            method: 'mass_stream_creation',
            intensity: 1000,
            target_resource: 'contract_storage',
        });
        
        vectors.append(DoSAttackVector {
            attack_type: 'gas_limit_attack',
            method: 'complex_calculations',
            intensity: 100,
            target_resource: 'computation',
        });
        
        vectors.append(DoSAttackVector {
            attack_type: 'memory_exhaustion',
            method: 'large_data_structures',
            intensity: 50,
            target_resource: 'memory',
        });
        
        vectors
    }

    // Social engineering attack scenarios
    fn get_social_engineering_scenarios() -> Array<SocialEngineeringScenario> {
        let mut scenarios = ArrayTrait::new();
        
        scenarios.append(SocialEngineeringScenario {
            attack_type: 'phishing',
            target: 'user_credentials',
            method: 'fake_login_page',
            indicators: array!['suspicious_url', 'ssl_mismatch', 'typos'],
        });
        
        scenarios.append(SocialEngineeringScenario {
            attack_type: 'pretexting',
            target: 'admin_access',
            method: 'fake_support_call',
            indicators: array!['urgency', 'authority_claim', 'information_request'],
        });
        
        scenarios
    }
}

// Data structures for security test scenarios
#[derive(Drop, Clone)]
struct TimingAttackScenario {
    operation: felt252,
    correct_input: felt252,
    incorrect_inputs: Array<felt252>,
    expected_timing_difference: u64,
}

#[derive(Drop, Clone)]
struct RaceConditionScenario {
    operation: felt252,
    concurrent_operations: u32,
    expected_success_count: u32,
    resource_type: felt252,
}

#[derive(Drop, Clone)]
struct CryptoAttackVector {
    attack_type: felt252,
    target: felt252,
    payload: Array<felt252>,
    expected_vulnerability: bool,
}

#[derive(Drop, Clone)]
struct BusinessLogicAttack {
    attack_name: felt252,
    target_function: felt252,
    malicious_parameters: Array<felt252>,
    expected_result: felt252,
}

#[derive(Drop, Clone)]
struct DoSAttackVector {
    attack_type: felt252,
    method: felt252,
    intensity: u32,
    target_resource: felt252,
}

#[derive(Drop, Clone)]
struct SocialEngineeringScenario {
    attack_type: felt252,
    target: felt252,
    method: felt252,
    indicators: Array<felt252>,
}