const { BitFlowClient } = require('@bitflow/sdk');

async function basicExample() {
  // Initialize client
  const client = new BitFlowClient({
    apiKey: process.env.BITFLOW_API_KEY,
    baseUrl: 'https://api.bitflow.dev'
  });

  try {
    console.log('=== BitFlow SDK Basic Usage Example ===\n');

    // 1. Create a payment stream
    console.log('1. Creating payment stream...');
    const stream = await client.createStream({
      recipient: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12',
      amount: '1000000',  // 1M units
      rate: '100',        // 100 units per second
      duration: 10000     // 10,000 seconds
    });
    
    console.log(`✓ Stream created: ${stream.id}`);
    console.log(`  Recipient: ${stream.recipient}`);
    console.log(`  Rate: ${stream.ratePerSecond} units/second`);
    console.log(`  Duration: ${(stream.endTime - stream.startTime)} seconds\n`);

    // 2. Get all streams
    console.log('2. Fetching user streams...');
    const streamsResponse = await client.getStreams({ limit: 5 });
    console.log(`✓ Found ${streamsResponse.streams.length} streams`);
    
    streamsResponse.streams.forEach((s, index) => {
      console.log(`  ${index + 1}. ${s.id} - ${s.isActive ? 'Active' : 'Inactive'}`);
    });
    console.log();

    // 3. Get specific stream details
    console.log('3. Getting stream details...');
    const streamDetails = await client.getStream(stream.id);
    console.log(`✓ Stream ${streamDetails.id}:`);
    console.log(`  Total Amount: ${streamDetails.totalAmount}`);
    console.log(`  Withdrawn: ${streamDetails.withdrawnAmount}`);
    console.log(`  Remaining: ${BigInt(streamDetails.totalAmount) - BigInt(streamDetails.withdrawnAmount)}\n`);

    // 4. Create subscription plan
    console.log('4. Creating subscription plan...');
    const plan = await client.createSubscriptionPlan({
      name: 'Basic Plan',
      description: 'Basic streaming service',
      price: '50000',     // 50K units
      interval: 2592000,  // 30 days
      maxSubscribers: 100
    });
    
    console.log(`✓ Subscription plan created: ${plan.id}`);
    console.log(`  Name: ${plan.name}`);
    console.log(`  Price: ${plan.price} units per ${plan.interval} seconds\n`);

    // 5. Subscribe to the plan
    console.log('5. Subscribing to plan...');
    const subscriptionId = await client.subscribe({
      planId: plan.id,
      duration: 7776000,  // 90 days
      autoRenew: false
    });
    
    console.log(`✓ Subscription created: ${subscriptionId}\n`);

    // 6. Set up webhook
    console.log('6. Setting up webhook...');
    const webhook = await client.createWebhook({
      url: 'https://your-app.com/webhooks/bitflow',
      events: ['stream.created', 'payment.received'],
      description: 'Example webhook endpoint'
    });
    
    console.log(`✓ Webhook created: ${webhook.id}`);
    console.log(`  URL: ${webhook.url}`);
    console.log(`  Events: ${webhook.events.join(', ')}`);
    console.log(`  Secret: ${webhook.secret.substring(0, 8)}...\n`);

    // 7. Test webhook
    console.log('7. Testing webhook...');
    const testResult = await client.testWebhook(webhook.id);
    console.log(`✓ Webhook test result:`, testResult);

    console.log('\n=== Example completed successfully! ===');

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code) {
      console.error('   Code:', error.code);
    }
    if (error.statusCode) {
      console.error('   Status:', error.statusCode);
    }
  }
}

// Run the example
if (require.main === module) {
  basicExample().catch(console.error);
}

module.exports = { basicExample };