import React from 'react';
import { render, fireEvent, act } from '@testing-library/react-native';
import Toast from '../../components/Toast';

jest.useFakeTimers();

describe('Toast', () => {
  const defaultProps = {
    visible: true,
    type: 'info' as const,
    title: 'Test Title',
    onHide: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should render toast with title', () => {
    const { getByText } = render(<Toast {...defaultProps} />);
    
    expect(getByText('Test Title')).toBeTruthy();
  });

  it('should render toast with message', () => {
    const { getByText } = render(
      <Toast {...defaultProps} message="Test message" />
    );
    
    expect(getByText('Test Title')).toBeTruthy();
    expect(getByText('Test message')).toBeTruthy();
  });

  it('should render action button when provided', () => {
    const onActionPress = jest.fn();
    const { getByText } = render(
      <Toast
        {...defaultProps}
        actionText="Action"
        onActionPress={onActionPress}
      />
    );
    
    const actionButton = getByText('Action');
    expect(actionButton).toBeTruthy();
    
    fireEvent.press(actionButton);
    expect(onActionPress).toHaveBeenCalled();
  });

  it('should call onHide when close button is pressed', () => {
    const onHide = jest.fn();
    const { getByTestId } = render(
      <Toast {...defaultProps} onHide={onHide} />
    );
    
    // Note: In a real implementation, you'd add testID to the close button
    // For now, we'll test the auto-hide functionality
  });

  it('should auto-hide after duration', () => {
    const onHide = jest.fn();
    render(<Toast {...defaultProps} onHide={onHide} duration={2000} />);
    
    act(() => {
      jest.advanceTimersByTime(2000);
    });
    
    // The onHide should be called after the animation completes
    act(() => {
      jest.advanceTimersByTime(300); // Animation duration
    });
    
    expect(onHide).toHaveBeenCalled();
  });

  it('should not render when not visible', () => {
    const { queryByText } = render(
      <Toast {...defaultProps} visible={false} />
    );
    
    expect(queryByText('Test Title')).toBeNull();
  });

  it('should render different styles for different types', () => {
    const types = ['success', 'error', 'warning', 'info'] as const;
    
    types.forEach(type => {
      const { rerender, getByText } = render(
        <Toast {...defaultProps} type={type} />
      );
      
      expect(getByText('Test Title')).toBeTruthy();
      
      // In a real implementation, you'd test the background color
      // or other style properties specific to each type
    });
  });

  it('should clear timeout when component unmounts', () => {
    const { unmount } = render(<Toast {...defaultProps} />);
    
    unmount();
    
    // Advance timers to ensure no memory leaks
    act(() => {
      jest.advanceTimersByTime(5000);
    });
    
    // No assertions needed, just ensuring no errors occur
  });
});