import React, { useEffect, useState, useRef } from 'react';
import { useSelector } from 'react-redux';
import { RootState } from '@redux/Store';
import { p2pService } from '@/services/p2p';
import { Order, PaymentMethod } from '@/types/p2p';
import { Button, Card, Typography, Grid, TextField, MenuItem, Box } from '@mui/material';
import { useSnackbar } from 'notistack';
import { clsx } from 'clsx';
import { CustomButton } from '@components/CustomButton';
import { LoadingLoader } from '@components/LoadingLoader';
import { useTranslation } from 'react-i18next';
import { LocalRxdbDatabase } from '@database/local-rxdb';
import { useAppSelector } from '@redux/Store';
import AttachFileIcon from '@mui/icons-material/AttachFile';
import { Principal } from '@dfinity/principal';
import { hexToUint8Array } from '@/common/utils/hexadecimal';
import { toHoleBigInt } from '@/common/utils/amount';
import ICRC2TransferForm from '@/common/libs/icrcledger/ICRC2TransferForm';

interface Message {
  id: string;
  type: 'order' | 'message' | 'payment' | 'image';
  content: string;
  sender: 'validator' | 'user';
  timestamp: Date;
  orderDetails?: {
    id: string;
    amount: number;
    price: number;
    status: string;
    paymentMethod: PaymentMethod;
  };
  isNew?: boolean;
  imageUrl?: string;
  validatorId?: string;
}

// Add these constants
const ORDER_STATUS_TRACKING = {
  OPEN: "open",
  PAYMENT_PENDING: "payment_pending",
  PAYMENT_SUBMITTED: "payment_submitted",
  PAYMENT_VERIFIED: "payment_verified",
  COMPLETED: "completed",
  DISPUTED: "disputed",
  CANCELLED: "cancelled"
} as const;

export const P2P: React.FC = () => {
  const { enqueueSnackbar } = useSnackbar();
  const { userPrincipal } = useSelector((state: RootState) => state.auth);
  const principal = userPrincipal?.toString();
  const [orders, setOrders] = useState<Order[]>([]);
  const [newOrder, setNewOrder] = useState({
    amount: '',
    price: '',
    paymentMethod: ''
  });
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const { t } = useTranslation();
  const [loading, setLoading] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [selectedValidator, setSelectedValidator] = useState<string>('');
  const assets = useAppSelector((state) => state.asset.list.assets);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadData();
    loadPaymentMethods();
  }, []);

  const loadData = async () => {
    try {
      const availableOrders = await p2pService.getAvailableOrders();
      setOrders(availableOrders);
    } catch (error) {
      console.error('Error loading P2P data:', error);
      enqueueSnackbar('Failed to load P2P data', { variant: 'error' });
    }
  };

  const loadPaymentMethods = async () => {
    try {
      const methods = await p2pService.getPaymentMethods();
      setPaymentMethods(methods);
    } catch (error) {
      console.error('Error loading payment methods:', error);
      enqueueSnackbar('Failed to load payment methods', { variant: 'error' });
    }
  };

  const handleCreateOrder = async () => {
    if (!principal) {
      enqueueSnackbar('Please login to create an order', { variant: 'error' });
      return;
    }

    try {
      const selectedMethod = paymentMethods.find(m => m.id === newOrder.paymentMethod);
      if (!selectedMethod) {
        enqueueSnackbar('Please select a payment method', { variant: 'error' });
        return;
      }

      await p2pService.createOrder({
        sellerId: principal,
        amount: parseFloat(newOrder.amount),
        price: parseFloat(newOrder.price),
        paymentMethod: selectedMethod
      });
      enqueueSnackbar('Order created successfully', { variant: 'success' });
      setNewOrder({ amount: '', price: '', paymentMethod: '' });
      loadData();
    } catch (error) {
      console.error('Error creating order:', error);
      enqueueSnackbar('Failed to create order', { variant: 'error' });
    }
  };

  const handleAcceptOrder = async (order: Order) => {
    if (!principal) {
      enqueueSnackbar('Please login to accept order', { variant: 'error' });
      return;
    }

    try {
      await p2pService.lockTokensInEscrow(order);
      await p2pService.updateOrderStatus(order.id, "payment_pending");
      enqueueSnackbar('Order accepted successfully', { variant: 'success' });
      loadData();
    } catch (error) {
      console.error('Error accepting order:', error);
      enqueueSnackbar('Failed to accept order', { variant: 'error' });
    }
  };

  const handleVerifyPayment = async (orderId: string) => {
    if (!principal) {
      enqueueSnackbar('Please login to verify payment', { variant: 'error' });
      return;
    }

    try {
      const order = await p2pService.getOrderById(orderId);
      if (!order) {
        enqueueSnackbar('Order not found', { variant: 'error' });
        return;
      }

      if (order.sellerId !== principal) {
        enqueueSnackbar('Only the seller can verify payments', { variant: 'error' });
        return;
      }

      const success = await p2pService.verifyPayment(orderId);
      if (success) {
        enqueueSnackbar('Payment verified successfully', { variant: 'success' });
        loadData();
      } else {
        enqueueSnackbar('Failed to verify payment', { variant: 'error' });
      }
    } catch (error) {
      console.error('Error verifying payment:', error);
      enqueueSnackbar('Failed to verify payment', { variant: 'error' });
    }
  };

  const handleDispute = async (orderId: string) => {
    if (!principal) {
      enqueueSnackbar('Please login to dispute order', { variant: 'error' });
      return;
    }

    try {
      const order = await p2pService.getOrderById(orderId);
      if (!order) {
        enqueueSnackbar('Order not found', { variant: 'error' });
        return;
      }

      const success = await p2pService.disputeOrder(orderId);
      if (success) {
        enqueueSnackbar('Order disputed successfully', { variant: 'success' });
        loadData();
      } else {
        enqueueSnackbar('Failed to dispute order', { variant: 'error' });
      }
    } catch (error) {
      console.error('Error disputing order:', error);
      enqueueSnackbar('Failed to dispute order', { variant: 'error' });
    }
  };

  const handlePaymentReceived = async (orderId: string, amount: number) => {
    try {
      setLoading(true);
      await p2pService.updateOrderStatus(orderId, ORDER_STATUS_TRACKING.COMPLETED);
      
      const userAssets = assets.find((asset: { tokenSymbol: string }) => 
        asset.tokenSymbol === "WASTE"
      );
      
      if (userAssets) {
        const updatedAsset = {
          ...userAssets,
          subAccounts: userAssets.subAccounts.map(subAccount => ({
            ...subAccount,
            amount: (parseFloat(subAccount.amount) + amount).toString(),
            currency_amount: (parseFloat(subAccount.currency_amount || "0") + amount).toString()
          }))
        };
        
        await LocalRxdbDatabase.instance.updateAsset(userAssets.address, updatedAsset, { sync: true });
        
        setMessages((prev: Message[]) => [...prev, {
          id: Math.random().toString(),
          type: 'message',
          content: `Payment received and ${amount} WASTE tokens added to your wallet!`,
          sender: 'validator',
          timestamp: new Date(),
          isNew: true
        }]);
      }
    } catch (error) {
      console.error("Failed to process payment received:", error);
      setMessages((prev: Message[]) => [...prev, {
        id: Math.random().toString(),
        type: 'message',
        content: 'Failed to process payment. Please try again.',
        sender: 'validator',
        timestamp: new Date(),
        isNew: true
      }]);
    } finally {
      setLoading(false);
    }
  };

  const handleImageSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file && file.type.startsWith('image/')) {
      setSelectedImage(file);
      const reader = new FileReader();
      reader.onloadend = async () => {
        const newMessage: Message = {
          id: Math.random().toString(),
          type: 'image',
          content: 'Payment proof uploaded',
          sender: 'user',
          timestamp: new Date(),
          imageUrl: reader.result as string,
          orderDetails: selectedOrder ? {
            id: selectedOrder.id,
            amount: selectedOrder.amount,
            price: selectedOrder.price,
            status: selectedOrder.status,
            paymentMethod: selectedOrder.paymentMethod
          } : undefined,
          isNew: true,
          validatorId: selectedValidator
        };

        // Save to database
        try {
          await p2pService.updateOrderStatus(selectedOrder?.id || '', 'payment_submitted');
          await LocalRxdbDatabase.instance.createPaymentVerification({
            orderId: selectedOrder?.id || '',
            proof: reader.result as string,
            status: 'pending'
          });
          setMessages(prev => [...prev, newMessage]);
          enqueueSnackbar('Payment proof uploaded successfully', { variant: 'success' });
        } catch (error) {
          console.error('Error uploading payment proof:', error);
          enqueueSnackbar('Failed to upload payment proof', { variant: 'error' });
        }
      };
      reader.readAsDataURL(file);
    }
  };

  const renderMessage = (message: Message) => {
    if (message.type === 'image') {
      return (
        <div className={clsx(
          "flex flex-col gap-2 p-2 rounded-lg max-w-[80%]",
          message.sender === 'user' ? "ml-auto" : "",
          message.isNew ? "animate-slideDown" : ""
        )}>
          {message.imageUrl && (
            <>
              <img 
                src={message.imageUrl} 
                alt="Payment proof" 
                className="max-w-full rounded-lg"
              />
              {/* Add Payment Received button for validators */}
              {selectedValidator && message.orderDetails && (
                <CustomButton
                  className={clsx(
                    "mt-2 bg-green-500 text-white text-sm py-1",
                    "hover:bg-green-600"
                  )}
                  onClick={() => message.orderDetails && handlePaymentReceived(
                    message.orderDetails.id,
                    message.orderDetails.amount
                  )}
                  disabled={loading}
                >
                  {loading ? <LoadingLoader /> : t("Confirm Payment Received")}
                </CustomButton>
              )}
            </>
          )}
        </div>
      );
    }

    // ... rest of the renderMessage function
  };

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>
        P2P Exchange
      </Typography>

      {/* Create Order Form */}
      <Card sx={{ p: 2, mb: 3 }}>
        <Typography variant="h6" gutterBottom>
          Create New Order
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Amount"
              type="number"
              value={newOrder.amount}
              onChange={(e) => setNewOrder({ ...newOrder, amount: e.target.value })}
            />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField
              fullWidth
              label="Price"
              type="number"
              value={newOrder.price}
              onChange={(e) => setNewOrder({ ...newOrder, price: e.target.value })}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              fullWidth
              select
              label="Payment Method"
              value={newOrder.paymentMethod}
              onChange={(e) => setNewOrder({ ...newOrder, paymentMethod: e.target.value })}
            >
              {paymentMethods.map((method) => (
                <MenuItem key={method.id} value={method.id}>
                  {method.name}
                </MenuItem>
              ))}
            </TextField>
          </Grid>
          <Grid item xs={12}>
            <Button
              variant="contained"
              color="primary"
              onClick={handleCreateOrder}
              disabled={!newOrder.amount || !newOrder.price || !newOrder.paymentMethod}
            >
              Create Order
            </Button>
          </Grid>
        </Grid>
      </Card>

      {/* Active Orders */}
      <Typography variant="h5" gutterBottom>
        Available Orders
      </Typography>
      <Grid container spacing={2}>
        {orders.map((order) => (
          <Grid item xs={12} sm={6} md={4} key={order.id}>
            <Card sx={{ p: 2 }}>
              <Typography variant="h6">
                {order.amount} WASTE
              </Typography>
              <Typography>Price: {order.price} PHP</Typography>
              <Typography>Payment: {order.paymentMethod.name}</Typography>
              <Typography>Status: {order.status}</Typography>
              <Box sx={{ mt: 2, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                {/* Accept Order Button */}
                <Button
                  variant="contained"
                  color="primary"
                  onClick={() => handleAcceptOrder(order)}
                  disabled={order.sellerId === principal || order.status !== 'open'}
                  sx={{ flex: '1 1 auto' }}
                >
                  Accept Order
                </Button>
                
                {/* Verify Payment Button - Only shown to seller */}
                {order.sellerId === principal && order.status === 'payment_pending' && (
                  <Button
                    variant="contained"
                    color="success"
                    onClick={() => handleVerifyPayment(order.id)}
                    sx={{ flex: '1 1 auto' }}
                  >
                    Verify Payment
                  </Button>
                )}
                
                {/* Dispute Button - Shown to both parties */}
                {(order.status === 'payment_pending' || order.status === 'payment_submitted') && (
                  <Button
                    variant="contained"
                    color="error"
                    onClick={() => handleDispute(order.id)}
                    sx={{ flex: '1 1 auto' }}
                  >
                    Dispute
                  </Button>
                )}
              </Box>
              <Box sx={{ mt: 2, display: 'flex', gap: 1 }}>
                <input
                  type="file"
                  ref={fileInputRef}
                  className="hidden"
                  accept="image/*"
                  onChange={handleImageSelect}
                />
                <Button
                  variant="contained"
                  color="primary"
                  onClick={() => fileInputRef.current?.click()}
                  startIcon={<AttachFileIcon />}
                >
                  Upload Payment Proof
                </Button>
              </Box>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}; 