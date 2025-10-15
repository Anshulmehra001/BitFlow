use starknet::{ContractAddress, get_caller_address};
use crate::interfaces::stream_manager::IStreamManager;
use crate::types::{PaymentStream, BitFlowError};
use crate::utils::validation::validate_stream_parameters;
use crate::utils::time::get_current_time;
use crate::utils::math::calculate_available_amount;

#[starknet::contract]
pub mod StreamManager {
    use super::*;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map
    };

    #[storage]
    struct Storage {
        // Stream storage
        streams: Map<u256, PaymentStream>,
        stream_count: u256,
        
        // Stream pause state tracking
        paused_streams: Map<u256, bool>,
        pause_timestamps: Map<u256, u64>,
        total_paused_time: Map<u256, u64>,
        
        // User stream mappings
        user_streams: Map<(ContractAddress, u256), u256>, // (user, index) -> stream_id
        user_stream_count: Map<ContractAddress, u256>,
        
        // Automatic payment tracking
        last_payment_time: Map<u256, u64>,
        accumulated_payments: Map<u256, u256>,
        
        // Contract owner for administrative functions
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StreamCreated: StreamCreated,
        StreamCancelled: StreamCancelled,
        StreamPaused: StreamPaused,
        StreamResumed: StreamResumed,
        StreamWithdrawal: StreamWithdrawal,
        AutomaticPayment: AutomaticPayment,
        StreamCompleted: StreamCompleted,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamCreated {
        #[key]
        pub stream_id: u256,
        #[key]
        pub sender: ContractAddress,
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
        pub rate: u256,
        pub duration: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamCancelled {
        #[key]
        pub stream_id: u256,
        #[key]
        pub cancelled_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamPaused {
        #[key]
        pub stream_id: u256,
        #[key]
        pub paused_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamResumed {
        #[key]
        pub stream_id: u256,
        #[key]
        pub resumed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamWithdrawal {
        #[key]
        pub stream_id: u256,
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AutomaticPayment {
        #[key]
        pub stream_id: u256,
        #[key]
        pub recipient: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StreamCompleted {
        #[key]
        pub stream_id: u256,
        pub total_streamed: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.stream_count.write(0);
    }

    #[abi(embed_v0)]
    impl StreamManagerImpl of IStreamManager<ContractState> {
        /// Creates a new payment stream
        fn create_stream(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            rate: u256,
            duration: u64
        ) -> u256 {
            // Validate input parameters
            validate_stream_parameters(recipient, amount, rate, duration)
                .expect('Invalid stream parameters');

            let caller = get_caller_address();
            let current_time = get_current_time();
            
            // Generate new stream ID
            let stream_id = self.stream_count.read() + 1;
            self.stream_count.write(stream_id);

            // Create the payment stream
            let stream = PaymentStream {
                id: stream_id,
                sender: caller,
                recipient,
                total_amount: amount,
                rate_per_second: rate,
                start_time: current_time,
                end_time: current_time + duration,
                withdrawn_amount: 0,
                is_active: true,
                yield_enabled: false, // Default to false, can be enabled later
            };

            // Store the stream
            self.streams.write(stream_id, stream);

            // Initialize automatic payment tracking
            self.last_payment_time.write(stream_id, 0);
            self.accumulated_payments.write(stream_id, 0);

            // Add to sender's stream list
            self._add_user_stream(caller, stream_id);
            
            // Add to recipient's stream list
            self._add_user_stream(recipient, stream_id);

            // Emit event
            self.emit(StreamCreated {
                stream_id,
                sender: caller,
                recipient,
                amount,
                rate,
                duration,
            });

            stream_id
        }

        /// Cancels an active payment stream
        fn cancel_stream(ref self: ContractState, stream_id: u256) -> bool {
            let caller = get_caller_address();
            let mut stream = self.streams.read(stream_id);
            
            // Validate stream exists and is active
            assert(stream.id != 0, 'Stream not found');
            assert(stream.is_active, 'Stream not active');
            
            // Only sender can cancel stream
            assert(caller == stream.sender, 'Unauthorized access');

            // Mark stream as inactive
            stream.is_active = false;
            self.streams.write(stream_id, stream);

            // Emit event
            self.emit(StreamCancelled {
                stream_id,
                cancelled_by: caller,
            });

            true
        }

        /// Pauses an active payment stream
        fn pause_stream(ref self: ContractState, stream_id: u256) -> bool {
            let caller = get_caller_address();
            let stream = self.streams.read(stream_id);
            
            // Validate stream exists and is active
            assert(stream.id != 0, 'Stream not found');
            assert(stream.is_active, 'Stream not active');
            assert(!self.paused_streams.read(stream_id), 'Stream already paused');
            
            // Only sender or recipient can pause stream
            assert(caller == stream.sender || caller == stream.recipient, 'Unauthorized access');

            // Mark stream as paused and record timestamp
            self.paused_streams.write(stream_id, true);
            self.pause_timestamps.write(stream_id, get_current_time());

            // Emit event
            self.emit(StreamPaused {
                stream_id,
                paused_by: caller,
            });

            true
        }

        /// Resumes a paused payment stream
        fn resume_stream(ref self: ContractState, stream_id: u256) -> bool {
            let caller = get_caller_address();
            let stream = self.streams.read(stream_id);
            
            // Validate stream exists and is active
            assert(stream.id != 0, 'Stream not found');
            assert(stream.is_active, 'Stream not active');
            assert(self.paused_streams.read(stream_id), 'Stream not paused');
            
            // Only sender or recipient can resume stream
            assert(caller == stream.sender || caller == stream.recipient, 'Unauthorized access');

            // Calculate total paused time and update
            let pause_start = self.pause_timestamps.read(stream_id);
            let current_time = get_current_time();
            let pause_duration = current_time - pause_start;
            let total_paused = self.total_paused_time.read(stream_id) + pause_duration;
            
            // Update pause state
            self.paused_streams.write(stream_id, false);
            self.pause_timestamps.write(stream_id, 0);
            self.total_paused_time.write(stream_id, total_paused);

            // Emit event
            self.emit(StreamResumed {
                stream_id,
                resumed_by: caller,
            });

            true
        }

        /// Allows recipient to withdraw available funds from a stream
        fn withdraw_from_stream(ref self: ContractState, stream_id: u256) -> u256 {
            let caller = get_caller_address();
            let mut stream = self.streams.read(stream_id);
            
            // Validate stream exists and is active
            assert(stream.id != 0, 'Stream not found');
            assert(stream.is_active, 'Stream not active');
            
            // Only recipient can withdraw
            assert(caller == stream.recipient, 'Unauthorized access');
            
            // Calculate available balance
            let available_amount = self._calculate_withdrawable_balance(stream_id);
            assert(available_amount > 0, 'No funds available');

            // Update withdrawn amount
            stream.withdrawn_amount += available_amount;
            self.streams.write(stream_id, stream);

            // Emit event
            self.emit(StreamWithdrawal {
                stream_id,
                recipient: caller,
                amount: available_amount,
            });

            available_amount
        }

        /// Gets the current withdrawable balance for a stream
        fn get_stream_balance(self: @ContractState, stream_id: u256) -> u256 {
            self._calculate_withdrawable_balance(stream_id)
        }

        /// Gets complete stream information
        fn get_stream(self: @ContractState, stream_id: u256) -> PaymentStream {
            let stream = self.streams.read(stream_id);
            assert(stream.id != 0, 'Stream not found');
            stream
        }

        /// Gets all stream IDs for a specific user (sender or recipient)
        fn get_user_streams(self: @ContractState, user: ContractAddress) -> Array<u256> {
            let mut streams = ArrayTrait::new();
            let count = self.user_stream_count.read(user);
            
            let mut i = 0;
            while i < count {
                let stream_id = self.user_streams.read((user, i));
                streams.append(stream_id);
                i += 1;
            };
            
            streams
        }

        /// Checks if a stream is active and valid
        fn is_stream_active(self: @ContractState, stream_id: u256) -> bool {
            let stream = self.streams.read(stream_id);
            stream.id != 0 && stream.is_active && !self.paused_streams.read(stream_id)
        }

        /// Gets the total number of streams created
        fn get_stream_count(self: @ContractState) -> u256 {
            self.stream_count.read()
        }

        /// Checks if a stream is currently paused
        fn is_stream_paused(self: @ContractState, stream_id: u256) -> bool {
            let stream = self.streams.read(stream_id);
            stream.id != 0 && self.paused_streams.read(stream_id)
        }

        /// Processes automatic payment distribution for a stream
        fn process_automatic_payment(ref self: ContractState, stream_id: u256) -> u256 {
            let mut stream = self.streams.read(stream_id);
            
            // Validate stream exists and is active
            assert(stream.id != 0, 'Stream not found');
            assert(stream.is_active, 'Stream not active');
            assert(!self.paused_streams.read(stream_id), 'Stream is paused');
            
            let current_time = get_current_time();
            let last_payment = self.last_payment_time.read(stream_id);
            
            // If this is the first payment, set last payment time to stream start
            let effective_last_payment = if last_payment == 0 {
                stream.start_time
            } else {
                last_payment
            };
            
            // Calculate payment amount since last payment
            let payment_amount = self._calculate_payment_since_last_update(stream_id, current_time);
            
            if payment_amount > 0 {
                // Update accumulated payments and last payment time
                let current_accumulated = self.accumulated_payments.read(stream_id);
                self.accumulated_payments.write(stream_id, current_accumulated + payment_amount);
                self.last_payment_time.write(stream_id, current_time);
                
                // Check if stream is completed
                let total_distributed = current_accumulated + payment_amount;
                if total_distributed >= stream.total_amount {
                    // Mark stream as completed
                    stream.is_active = false;
                    self.streams.write(stream_id, stream);
                    
                    self.emit(StreamCompleted {
                        stream_id,
                        total_streamed: stream.total_amount,
                    });
                }
                
                // Emit automatic payment event
                self.emit(AutomaticPayment {
                    stream_id,
                    recipient: stream.recipient,
                    amount: payment_amount,
                    timestamp: current_time,
                });
            }
            
            payment_amount
        }

        /// Processes automatic payments for multiple streams in batch
        fn batch_process_payments(ref self: ContractState, stream_ids: Array<u256>) -> u256 {
            let mut total_processed = 0_u256;
            let mut i = 0;
            
            while i < stream_ids.len() {
                let stream_id = *stream_ids.at(i);
                
                // Check if stream is valid and active before processing
                let stream = self.streams.read(stream_id);
                if stream.id != 0 && stream.is_active && !self.paused_streams.read(stream_id) {
                    let amount = self.process_automatic_payment(stream_id);
                    total_processed += amount;
                }
                // Skip invalid, inactive, or paused streams silently
                
                i += 1;
            };
            
            total_processed
        }

        /// Gets the accumulated payments for a stream (total distributed automatically)
        fn get_accumulated_payments(self: @ContractState, stream_id: u256) -> u256 {
            self.accumulated_payments.read(stream_id)
        }

        /// Gets the last payment timestamp for a stream
        fn get_last_payment_time(self: @ContractState, stream_id: u256) -> u64 {
            self.last_payment_time.read(stream_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Adds a stream ID to a user's stream list
        fn _add_user_stream(ref self: ContractState, user: ContractAddress, stream_id: u256) {
            let count = self.user_stream_count.read(user);
            self.user_streams.write((user, count), stream_id);
            self.user_stream_count.write(user, count + 1);
        }

        /// Calculates the withdrawable balance for a stream accounting for pauses
        fn _calculate_withdrawable_balance(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            
            // Return 0 if stream doesn't exist or is not active
            if stream.id == 0 || !stream.is_active {
                return 0;
            }

            let current_time = get_current_time();
            let mut effective_elapsed_time = 0_u64;

            // If stream is currently paused, calculate up to pause time
            if self.paused_streams.read(stream_id) {
                let pause_start = self.pause_timestamps.read(stream_id);
                let time_before_pause = if pause_start > stream.start_time {
                    pause_start - stream.start_time
                } else {
                    0
                };
                effective_elapsed_time = time_before_pause;
            } else {
                // Stream is not paused, calculate normal elapsed time
                if current_time > stream.start_time {
                    effective_elapsed_time = current_time - stream.start_time;
                }
            }

            // Subtract total paused time from effective elapsed time
            let total_paused = self.total_paused_time.read(stream_id);
            if effective_elapsed_time > total_paused {
                effective_elapsed_time -= total_paused;
            } else {
                effective_elapsed_time = 0;
            }

            // Calculate streamed amount based on effective elapsed time
            let streamed_amount = stream.rate_per_second * effective_elapsed_time.into();
            
            // Cap at total amount
            let max_streamed = if streamed_amount > stream.total_amount {
                stream.total_amount
            } else {
                streamed_amount
            };
            
            // Subtract already withdrawn amount and accumulated automatic payments
            let accumulated = self.accumulated_payments.read(stream_id);
            let total_distributed = stream.withdrawn_amount + accumulated;
            
            if max_streamed > total_distributed {
                max_streamed - total_distributed
            } else {
                0
            }
        }

        /// Calculates payment amount since last automatic payment update
        fn _calculate_payment_since_last_update(self: @ContractState, stream_id: u256, current_time: u64) -> u256 {
            let stream = self.streams.read(stream_id);
            let last_payment = self.last_payment_time.read(stream_id);
            
            // If this is the first payment, use stream start time
            let effective_last_payment = if last_payment == 0 {
                stream.start_time
            } else {
                last_payment
            };
            
            // Don't process if current time is before or equal to last payment time
            if current_time <= effective_last_payment {
                return 0;
            }
            
            // Calculate time elapsed since last payment
            let time_elapsed = current_time - effective_last_payment;
            
            // Calculate payment amount for this period
            let payment_amount = stream.rate_per_second * time_elapsed.into();
            
            // Check total distributed so far
            let accumulated = self.accumulated_payments.read(stream_id);
            let total_distributed = stream.withdrawn_amount + accumulated;
            
            // Cap payment to not exceed total stream amount
            let remaining_amount = if stream.total_amount > total_distributed {
                stream.total_amount - total_distributed
            } else {
                0
            };
            
            if payment_amount > remaining_amount {
                remaining_amount
            } else {
                payment_amount
            }
        }
    }
}