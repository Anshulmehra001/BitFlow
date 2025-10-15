// Winston logging configuration for BitFlow

const winston = require('winston');
const path = require('path');

// Define log levels
const logLevels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define log colors
const logColors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white',
};

winston.addColors(logColors);

// Create log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`,
  ),
);

// Define transports
const transports = [
  // Console transport for development
  new winston.transports.Console({
    format: logFormat,
    level: process.env.LOG_LEVEL || 'info',
  }),
  
  // File transport for all logs
  new winston.transports.File({
    filename: path.join('/var/log/bitflow', 'combined.log'),
    level: 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.json()
    ),
    maxsize: 100 * 1024 * 1024, // 100MB
    maxFiles: 10,
  }),
  
  // File transport for error logs
  new winston.transports.File({
    filename: path.join('/var/log/bitflow', 'error.log'),
    level: 'error',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.json()
    ),
    maxsize: 50 * 1024 * 1024, // 50MB
    maxFiles: 20,
  }),
  
  // File transport for audit logs
  new winston.transports.File({
    filename: path.join('/var/log/bitflow', 'audit.log'),
    level: 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.json(),
      winston.format.printf((info) => {
        if (info.audit) {
          return JSON.stringify({
            timestamp: info.timestamp,
            level: info.level,
            message: info.message,
            userId: info.userId,
            action: info.action,
            resource: info.resource,
            ip: info.ip,
            userAgent: info.userAgent,
          });
        }
        return JSON.stringify(info);
      })
    ),
    maxsize: 100 * 1024 * 1024, // 100MB
    maxFiles: 50,
  }),
];

// Add Sentry transport for production
if (process.env.NODE_ENV === 'production' && process.env.SENTRY_DSN) {
  const Sentry = require('@sentry/node');
  const SentryTransport = require('winston-sentry-log');
  
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
  });
  
  transports.push(
    new SentryTransport({
      sentry: Sentry,
      level: 'error',
    })
  );
}

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  levels: logLevels,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports,
  exitOnError: false,
});

// Add request logging middleware
logger.requestLogger = (req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      userId: req.user?.id,
    };
    
    if (res.statusCode >= 400) {
      logger.warn('HTTP Request', logData);
    } else {
      logger.http('HTTP Request', logData);
    }
  });
  
  next();
};

// Add audit logging function
logger.audit = (action, resource, userId, req) => {
  logger.info('Audit Log', {
    audit: true,
    action,
    resource,
    userId,
    ip: req?.ip,
    userAgent: req?.get('User-Agent'),
  });
};

// Add stream event logging
logger.streamEvent = (event, streamId, userId, data = {}) => {
  logger.info('Stream Event', {
    event,
    streamId,
    userId,
    ...data,
  });
};

// Add bridge event logging
logger.bridgeEvent = (event, transactionId, data = {}) => {
  logger.info('Bridge Event', {
    event,
    transactionId,
    ...data,
  });
};

// Add yield event logging
logger.yieldEvent = (event, streamId, amount, protocol) => {
  logger.info('Yield Event', {
    event,
    streamId,
    amount,
    protocol,
  });
};

module.exports = logger;