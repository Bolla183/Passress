export class ApiError extends Error {
  readonly statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.statusCode = statusCode;
  }
}

export class NotFoundError extends ApiError {
  constructor(message = 'Not found.') {
    super(404, message);
  }
}

export class BadRequestError extends ApiError {
  constructor(message: string) {
    super(400, message);
  }
}
