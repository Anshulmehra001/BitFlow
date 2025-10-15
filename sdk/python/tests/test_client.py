"""Tests for BitFlow Python client."""

import pytest
import responses
from bitflow import (
    BitFlowClient,
    CreateStreamRequest,
    StreamFilters,
    StreamStatus,
    AuthenticationError,
    ValidationError,
    NotFoundError,
)


@pytest.fixture
def client():
    return BitFlowClient(api_key="test-api-key", base_url="https://api.test.com")


@pytest.fixture
def mock_stream_data():
    return {
        "id": "stream_123",
        "sender": "0x123",
        "recipient": "0x456", 
        "totalAmount": "1000000",
        "ratePerSecond": "100",
        "startTime": 1640995200,
        "endTime": 1641081600,
        "withdrawnAmount": "360000",
        "isActive": True
    }


class TestBitFlowClient:
    
    @responses.activate
    def test_create_stream_success(self, client, mock_stream_data):
        responses.add(
            responses.POST,
            "https://api.test.com/api/streams",
            json={"data": {"streamId": "stream_123", "stream": mock_stream_data}},
            status=201
        )
        
        request = CreateStreamRequest(
            recipient="0x456",
            amount="1000000",
            rate="100",
            duration=10000
        )
        
        stream = client.create_stream(request)
        
        assert stream.id == "stream_123"
        assert stream.recipient == "0x456"
        assert stream.total_amount == "1000000"
        assert stream.is_active is True

    @responses.activate
    def test_create_stream_validation_error(self, client):
        responses.add(
            responses.POST,
            "https://api.test.com/api/streams",
            json={"error": {"message": "Invalid recipient address", "code": "VALIDATION_ERROR"}},
            status=400
        )
        
        request = CreateStreamRequest(
            recipient="invalid-address",
            amount="1000000", 
            rate="100",
            duration=10000
        )
        
        with pytest.raises(ValidationError) as exc_info:
            client.create_stream(request)
        
        assert "Invalid recipient address" in str(exc_info.value)

    @responses.activate
    def test_get_streams_success(self, client, mock_stream_data):
        responses.add(
            responses.GET,
            "https://api.test.com/api/streams",
            json={
                "streams": [mock_stream_data],
                "pagination": {"limit": 20, "offset": 0, "total": 1}
            },
            status=200
        )
        
        response = client.get_streams()
        
        assert len(response.streams) == 1
        assert response.streams[0].id == "stream_123"
        assert response.pagination["total"] == 1

    @responses.activate
    def test_get_streams_with_filters(self, client, mock_stream_data):
        responses.add(
            responses.GET,
            "https://api.test.com/api/streams?status=active&limit=10&offset=0",
            json={
                "streams": [mock_stream_data],
                "pagination": {"limit": 10, "offset": 0, "total": 1}
            },
            status=200
        )
        
        filters = StreamFilters(
            status=StreamStatus.ACTIVE,
            limit=10,
            offset=0
        )
        
        response = client.get_streams(filters)
        
        assert len(response.streams) == 1
        assert response.pagination["limit"] == 10

    @responses.activate
    def test_get_stream_success(self, client, mock_stream_data):
        responses.add(
            responses.GET,
            "https://api.test.com/api/streams/stream_123",
            json={"data": {"stream": mock_stream_data}},
            status=200
        )
        
        stream = client.get_stream("stream_123")
        
        assert stream.id == "stream_123"
        assert stream.withdrawn_amount == "360000"

    @responses.activate
    def test_get_stream_not_found(self, client):
        responses.add(
            responses.GET,
            "https://api.test.com/api/streams/nonexistent",
            json={"error": {"message": "Stream not found", "code": "NOT_FOUND"}},
            status=404
        )
        
        with pytest.raises(NotFoundError):
            client.get_stream("nonexistent")

    @responses.activate
    def test_cancel_stream_success(self, client):
        responses.add(
            responses.POST,
            "https://api.test.com/api/streams/stream_123/cancel",
            json={"message": "Stream cancelled successfully"},
            status=200
        )
        
        # Should not raise an exception
        client.cancel_stream("stream_123")

    @responses.activate
    def test_withdraw_from_stream_success(self, client):
        responses.add(
            responses.POST,
            "https://api.test.com/api/streams/stream_123/withdraw",
            json={"data": {"withdrawnAmount": "500000"}},
            status=200
        )
        
        withdrawn = client.withdraw_from_stream("stream_123")
        
        assert withdrawn == "500000"

    @responses.activate
    def test_authentication_error(self, client):
        responses.add(
            responses.GET,
            "https://api.test.com/api/streams",
            json={"error": {"message": "Invalid API key", "code": "UNAUTHORIZED"}},
            status=401
        )
        
        with pytest.raises(AuthenticationError):
            client.get_streams()

    def test_client_initialization(self):
        client = BitFlowClient(
            api_key="test-key",
            base_url="https://custom.api.com",
            timeout=60,
            max_retries=5
        )
        
        assert client.api_key == "test-key"
        assert client.base_url == "https://custom.api.com"
        assert client.timeout == 60