"""
Tests for Bonjour/mDNS service advertisement.

Tests the BonjourAdvertiser class which advertises the UnaMentis server
on the local network for client auto-discovery.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

# Import the module under test
import bonjour_advertiser
from bonjour_advertiser import BonjourAdvertiser, start_bonjour_advertising


class TestBonjourAdvertiserInit:
    """Tests for BonjourAdvertiser initialization."""

    def test_init_with_defaults(self):
        """Test initialization with default parameters."""
        advertiser = BonjourAdvertiser()

        assert advertiser.gateway_port == 11400
        assert advertiser.management_port == 8766
        assert advertiser.service_name.startswith("UnaMentis-")
        assert advertiser._is_running is False
        assert advertiser._zeroconf is None
        assert advertiser._service_info is None

    def test_init_with_custom_ports(self):
        """Test initialization with custom port numbers."""
        advertiser = BonjourAdvertiser(gateway_port=9000, management_port=9001)

        assert advertiser.gateway_port == 9000
        assert advertiser.management_port == 9001

    def test_init_with_custom_service_name(self):
        """Test initialization with custom service name."""
        advertiser = BonjourAdvertiser(service_name="MyCustomServer")

        assert advertiser.service_name == "MyCustomServer"

    def test_service_type_constant(self):
        """Test that service type is correctly defined."""
        assert BonjourAdvertiser.SERVICE_TYPE == "_unamentis._tcp.local."


class TestBonjourAdvertiserServiceName:
    """Tests for service name generation."""

    def test_get_service_name_basic(self):
        """Test basic service name generation from hostname."""
        advertiser = BonjourAdvertiser()
        with patch("socket.gethostname", return_value="myhost"):
            name = advertiser._get_service_name()
            assert name == "UnaMentis-myhost"

    def test_get_service_name_removes_local_suffix(self):
        """Test that .local suffix is removed from hostname."""
        advertiser = BonjourAdvertiser()
        with patch("socket.gethostname", return_value="myhost.local"):
            name = advertiser._get_service_name()
            assert name == "UnaMentis-myhost"


class TestBonjourAdvertiserLocalIP:
    """Tests for local IP detection."""

    def test_get_local_ip_via_socket(self):
        """Test getting local IP via UDP socket method."""
        advertiser = BonjourAdvertiser()

        mock_socket = MagicMock()
        mock_socket.getsockname.return_value = ("192.168.1.100", 0)

        with patch("socket.socket", return_value=mock_socket):
            ip = advertiser._get_local_ip()
            assert ip == "192.168.1.100"
            mock_socket.connect.assert_called_once_with(("8.8.8.8", 80))
            mock_socket.close.assert_called_once()

    def test_get_local_ip_socket_failure_returns_none(self):
        """Test that socket failure returns None when no fallback available."""
        advertiser = BonjourAdvertiser()

        mock_socket = MagicMock()
        mock_socket.connect.side_effect = OSError("Network unreachable")

        with patch("socket.socket", return_value=mock_socket):
            with patch.dict("sys.modules", {"netifaces": None}):
                ip = advertiser._get_local_ip()
                # Returns None when socket fails and netifaces not available
                assert ip is None


class TestBonjourAdvertiserIsRunning:
    """Tests for is_running property."""

    def test_is_running_initially_false(self):
        """Test that is_running is False initially."""
        advertiser = BonjourAdvertiser()
        assert advertiser.is_running is False

    def test_is_running_reflects_internal_state(self):
        """Test that is_running reflects _is_running state."""
        advertiser = BonjourAdvertiser()
        advertiser._is_running = True
        assert advertiser.is_running is True

        advertiser._is_running = False
        assert advertiser.is_running is False


class TestBonjourAdvertiserStart:
    """Tests for starting the advertiser."""

    @pytest.mark.asyncio
    async def test_start_returns_false_when_zeroconf_not_available(self):
        """Test that start returns False when zeroconf is not installed."""
        advertiser = BonjourAdvertiser()

        with patch.object(bonjour_advertiser, "ZEROCONF_AVAILABLE", False):
            result = await advertiser.start()
            assert result is False
            assert advertiser.is_running is False

    @pytest.mark.asyncio
    async def test_start_returns_true_when_already_running(self):
        """Test that start returns True if already running."""
        advertiser = BonjourAdvertiser()
        advertiser._is_running = True

        with patch.object(bonjour_advertiser, "ZEROCONF_AVAILABLE", True):
            result = await advertiser.start()
            assert result is True

    @pytest.mark.asyncio
    async def test_start_returns_false_when_no_local_ip(self):
        """Test that start returns False when local IP cannot be determined."""
        advertiser = BonjourAdvertiser()

        with patch.object(bonjour_advertiser, "ZEROCONF_AVAILABLE", True):
            with patch.object(advertiser, "_get_local_ip", return_value=None):
                result = await advertiser.start()
                assert result is False
                assert advertiser.is_running is False

    @pytest.mark.asyncio
    async def test_start_success_with_mocked_zeroconf(self):
        """Test successful start with mocked zeroconf."""
        advertiser = BonjourAdvertiser()

        mock_async_zeroconf = MagicMock()
        mock_async_zeroconf.async_register_service = AsyncMock()

        mock_service_info = MagicMock()

        with patch.object(bonjour_advertiser, "ZEROCONF_AVAILABLE", True):
            with patch.object(advertiser, "_get_local_ip", return_value="192.168.1.100"):
                # Patch at module level with create=True since zeroconf may not be installed
                with patch.object(
                    bonjour_advertiser, "AsyncZeroconf",
                    return_value=mock_async_zeroconf,
                    create=True
                ):
                    with patch.object(
                        bonjour_advertiser, "ServiceInfo",
                        return_value=mock_service_info,
                        create=True
                    ):
                        result = await advertiser.start()

                        assert result is True
                        assert advertiser.is_running is True
                        mock_async_zeroconf.async_register_service.assert_called_once()

    @pytest.mark.asyncio
    async def test_start_handles_exception(self):
        """Test that start handles exceptions gracefully."""
        advertiser = BonjourAdvertiser()

        with patch.object(bonjour_advertiser, "ZEROCONF_AVAILABLE", True):
            with patch.object(advertiser, "_get_local_ip", return_value="192.168.1.100"):
                # Patch with create=True since zeroconf may not be installed
                with patch.object(
                    bonjour_advertiser, "ServiceInfo",
                    side_effect=Exception("Test error"),
                    create=True
                ):
                    result = await advertiser.start()
                    assert result is False
                    assert advertiser.is_running is False


class TestBonjourAdvertiserStop:
    """Tests for stopping the advertiser."""

    @pytest.mark.asyncio
    async def test_stop_when_not_running(self):
        """Test that stop does nothing when not running."""
        advertiser = BonjourAdvertiser()
        advertiser._is_running = False

        # Should not raise and should return immediately
        await advertiser.stop()
        assert advertiser.is_running is False

    @pytest.mark.asyncio
    async def test_stop_calls_cleanup(self):
        """Test that stop calls cleanup when running."""
        advertiser = BonjourAdvertiser()
        advertiser._is_running = True

        with patch.object(advertiser, "_cleanup", new_callable=AsyncMock) as mock_cleanup:
            await advertiser.stop()
            mock_cleanup.assert_called_once()


class TestBonjourAdvertiserCleanup:
    """Tests for cleanup method."""

    @pytest.mark.asyncio
    async def test_cleanup_unregisters_and_closes(self):
        """Test that cleanup unregisters service and closes zeroconf."""
        advertiser = BonjourAdvertiser()

        mock_zeroconf = MagicMock()
        mock_zeroconf.async_unregister_service = AsyncMock()
        mock_zeroconf.async_close = AsyncMock()

        mock_service_info = MagicMock()

        advertiser._zeroconf = mock_zeroconf
        advertiser._service_info = mock_service_info
        advertiser._is_running = True

        await advertiser._cleanup()

        mock_zeroconf.async_unregister_service.assert_called_once_with(mock_service_info)
        mock_zeroconf.async_close.assert_called_once()
        assert advertiser._zeroconf is None
        assert advertiser._service_info is None
        assert advertiser._is_running is False

    @pytest.mark.asyncio
    async def test_cleanup_handles_exception(self):
        """Test that cleanup handles exceptions gracefully."""
        advertiser = BonjourAdvertiser()

        mock_zeroconf = MagicMock()
        mock_zeroconf.async_unregister_service = AsyncMock(
            side_effect=Exception("Cleanup error")
        )
        mock_zeroconf.async_close = AsyncMock()

        advertiser._zeroconf = mock_zeroconf
        advertiser._service_info = MagicMock()
        advertiser._is_running = True

        # Should not raise
        await advertiser._cleanup()

        # State should be cleaned up regardless of exception
        assert advertiser._zeroconf is None
        assert advertiser._service_info is None
        assert advertiser._is_running is False

    @pytest.mark.asyncio
    async def test_cleanup_with_no_zeroconf(self):
        """Test cleanup when zeroconf is None."""
        advertiser = BonjourAdvertiser()
        advertiser._zeroconf = None
        advertiser._service_info = None
        advertiser._is_running = True

        await advertiser._cleanup()

        assert advertiser._is_running is False


class TestStartBonjourAdvertisingFunction:
    """Tests for the convenience function."""

    @pytest.mark.asyncio
    async def test_start_bonjour_advertising_success(self):
        """Test convenience function returns advertiser on success."""
        mock_advertiser = MagicMock()
        mock_advertiser.start = AsyncMock(return_value=True)

        with patch.object(
            bonjour_advertiser, "BonjourAdvertiser", return_value=mock_advertiser
        ):
            result = await start_bonjour_advertising(gateway_port=9000, management_port=9001)

            assert result is mock_advertiser
            mock_advertiser.start.assert_called_once()

    @pytest.mark.asyncio
    async def test_start_bonjour_advertising_failure(self):
        """Test convenience function returns None on failure."""
        mock_advertiser = MagicMock()
        mock_advertiser.start = AsyncMock(return_value=False)

        with patch.object(
            bonjour_advertiser, "BonjourAdvertiser", return_value=mock_advertiser
        ):
            result = await start_bonjour_advertising()

            assert result is None
            mock_advertiser.start.assert_called_once()

    @pytest.mark.asyncio
    async def test_start_bonjour_advertising_uses_default_ports(self):
        """Test convenience function uses default ports."""
        mock_advertiser = MagicMock()
        mock_advertiser.start = AsyncMock(return_value=True)

        with patch.object(
            bonjour_advertiser, "BonjourAdvertiser", return_value=mock_advertiser
        ) as mock_class:
            await start_bonjour_advertising()

            mock_class.assert_called_once_with(
                gateway_port=11400,
                management_port=8766
            )
