const validateStreamParams = ({ recipient, amount, rate, duration }) => {
  const errors = [];

  // Validate recipient address
  if (!recipient || typeof recipient !== 'string') {
    errors.push('Recipient address is required');
  } else if (!recipient.startsWith('0x') || recipient.length !== 66) {
    errors.push('Invalid recipient address format');
  }

  // Validate amount
  if (!amount || typeof amount !== 'string') {
    errors.push('Amount is required and must be a string');
  } else {
    try {
      const amountBigInt = BigInt(amount);
      if (amountBigInt <= 0) {
        errors.push('Amount must be greater than 0');
      }
    } catch {
      errors.push('Invalid amount format');
    }
  }

  // Validate rate
  if (!rate || typeof rate !== 'string') {
    errors.push('Rate is required and must be a string');
  } else {
    try {
      const rateBigInt = BigInt(rate);
      if (rateBigInt <= 0) {
        errors.push('Rate must be greater than 0');
      }
    } catch {
      errors.push('Invalid rate format');
    }
  }

  // Validate duration
  if (!duration || typeof duration !== 'number') {
    errors.push('Duration is required and must be a number');
  } else if (duration <= 0) {
    errors.push('Duration must be greater than 0');
  } else if (duration > 31536000) { // 1 year in seconds
    errors.push('Duration cannot exceed 1 year');
  }

  // Validate that total amount matches rate * duration
  if (errors.length === 0) {
    try {
      const amountBigInt = BigInt(amount);
      const rateBigInt = BigInt(rate);
      const expectedAmount = rateBigInt * BigInt(duration);
      
      if (amountBigInt !== expectedAmount) {
        errors.push('Amount must equal rate × duration');
      }
    } catch {
      // Already handled above
    }
  }

  return {
    isValid: errors.length === 0,
    error: errors.length > 0 ? errors.join(', ') : null
  };
};

const validateWalletAddress = (address) => {
  if (!address || typeof address !== 'string') {
    return false;
  }
  
  // Basic Starknet address validation
  return address.startsWith('0x') && address.length === 66;
};

const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateUrl = (url) => {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
};

module.exports = {
  validateStreamParams,
  validateWalletAddress,
  validateEmail,
  validateUrl
};