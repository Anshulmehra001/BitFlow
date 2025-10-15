const { ApiError } = require('../utils/errors');

const errorHandler = (err, req, res, next) => {
  console.error('API Error:', err);

  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      error: {
        message: err.message,
        code: err.code,
        timestamp: new Date().toISOString()
      }
    });
  }

  // Handle Starknet errors
  if (err.message && err.message.includes('starknet')) {
    return res.status(500).json({
      error: {
        message: 'Blockchain interaction failed',
        code: 'STARKNET_ERROR',
        timestamp: new Date().toISOString()
      }
    });
  }

  // Default error
  res.status(500).json({
    error: {
      message: 'Internal server error',
      code: 'INTERNAL_ERROR',
      timestamp: new Date().toISOString()
    }
  });
};

module.exports = { errorHandler };