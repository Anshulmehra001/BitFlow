class ApiError extends Error {
  constructor(statusCode, message, code = null) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.name = 'ApiError';
  }
}

const createError = {
  badRequest: (message, code = 'BAD_REQUEST') => new ApiError(400, message, code),
  unauthorized: (message = 'Unauthorized', code = 'UNAUTHORIZED') => new ApiError(401, message, code),
  forbidden: (message = 'Forbidden', code = 'FORBIDDEN') => new ApiError(403, message, code),
  notFound: (message = 'Not found', code = 'NOT_FOUND') => new ApiError(404, message, code),
  conflict: (message, code = 'CONFLICT') => new ApiError(409, message, code),
  internal: (message = 'Internal server error', code = 'INTERNAL_ERROR') => new ApiError(500, message, code)
};

module.exports = {
  ApiError,
  createError
};