const User = require('../models/userModel')
const jwt = require('jsonwebtoken')
const transporter = require('../utils/mailer')
const bcrypt = require('bcrypt')

const createToken = (user) => {
    return jwt.sign({
        _id: user._id,
        username: user.username,
        role: user.role
    }, process.env.SECRET, { expiresIn: '3d' })
}

const loginUser = async (req, res, next) => {
    const { identifier, password } = req.body

    try {
        const user = await User.login(identifier, password)

        const role = user.role
        const username = user.username

        //token
        const token = createToken(user)

        res.status(200).json({ username, token, role })
    } catch (error) {
        next(error)
    }
}

const signUpUser = async (req, res, next) => {
    const { username, email, password } = req.body

    try {
        const user = await User.signup(username, email, password)

        //token
        const token = jwt.sign({ _id: user._id }, process.env.SECRET, { expiresIn: '1h' });

        const verificationLink = `http://localhost:8000/api/auth/verify/${token}`


        const mail = await transporter.sendMail({
            from: `"MyApp" <${process.env.EMAIL_USER}>`,
            to: user.email,
            subject: 'Verify your email',
            html: `
            <h2>Welcome ${user.username}!</h2>
            <p>Click below to verify your account:</p>
            <a href="${verificationLink}">${verificationLink}</a>
        `,
        });
        console.log("mail: ", mail)

        res.status(201).json({ message: `${username} registered successfully. Please check your email and verify`, token })
    } catch (error) {
        next(error)
    }
}

const getUser = async (req, res, next) => {
    const { username } = req.params

    try {
        const user = await User.findOne({ username }).select("-password")
        if (!user) {
            return res.status(404).json({ error: 'user not found' })
        }
        res.status(200).json(user)
    } catch (error) {
        next(error)
    }
}

const verifyEmail = async (req, res, next) => {
    try {
        const { token } = req.params
        const decoded = jwt.verify(token, process.env.SECRET)
        console.log(decoded)
        const user = await User.findById(decoded._id)
        console.log(user)
        if (!user) return res.status(400).json({ error: "Invalid Token" })

        if (user.isVerified) {
            console.log("verified")
            return res.status(200).json({ message: "Already Verified" })
        }

        user.isVerified = true
        await user.save()

        res.status(200).json({ message: "Email verified successfully" })
    } catch (error) {
        console.log("Verification failed")
        next(error)
    }
}

const forgotPassword = async (req, res, next) => {
    try {
        const { email } = req.body
        if (!email) return res.status(400).json({ error: 'Email is required' })

        const normalizedEmail = email.trim().toLowerCase()
        const user = await User.findOne({ email: normalizedEmail }).select('+resetOtpHash +resetOtpExpires')
        if (!user) {
            return res.status(200).json({
                message: 'If an account exists for this email, a verification code has been sent.',
            })
        }

        const code = String(Math.floor(100000 + Math.random() * 900000))
        const salt = await bcrypt.genSalt(10)
        user.resetOtpHash = await bcrypt.hash(code, salt)
        user.resetOtpExpires = new Date(Date.now() + 15 * 60 * 1000)
        await user.save()

        await transporter.sendMail({
            from: `"Parental Control" <${process.env.EMAIL_USER}>`,
            to: normalizedEmail,
            subject: 'Your password reset code',
            html: `
                <h2>Password reset</h2>
                <p>Hi ${user.username},</p>
                <p>Your verification code is:</p>
                <p style="font-size: 32px; font-weight: bold; letter-spacing: 8px;">${code}</p>
                <p>This code expires in 15 minutes.</p>
                <p>If you didn't request this, you can ignore this email.</p>
            `,
        })

        console.log(`Password reset code for ${normalizedEmail}: ${code}`)

        res.status(200).json({
            message: 'If an account exists for this email, a verification code has been sent.',
        })
    } catch (error) {
        next(error)
    }
}

const resetPassword = async (req, res, next) => {
    try {
        const { email, code, newPassword } = req.body

        if (!email || !code || !newPassword) {
            return res.status(400).json({ error: 'Email, verification code, and new password are required' })
        }

        const validator = require('validator')
        if (!validator.isStrongPassword(newPassword)) {
            return res.status(400).json({ error: 'Password is not strong enough' })
        }

        const normalizedEmail = email.trim().toLowerCase()
        const user = await User.findOne({ email: normalizedEmail }).select('+resetOtpHash +resetOtpExpires')
        if (!user) return res.status(400).json({ error: 'Invalid or expired verification code' })

        if (!user.resetOtpHash || !user.resetOtpExpires || user.resetOtpExpires < new Date()) {
            return res.status(400).json({ error: 'Verification code has expired. Request a new one.' })
        }

        const match = await bcrypt.compare(String(code).trim(), user.resetOtpHash)
        if (!match) return res.status(400).json({ error: 'Invalid verification code' })

        const salt = await bcrypt.genSalt(10)
        user.password = await bcrypt.hash(newPassword, salt)
        user.resetOtpHash = undefined
        user.resetOtpExpires = undefined
        await user.save()

        res.status(200).json({ message: 'Password has been reset successfully' })
    } catch (error) {
        next(error)
    }
}
module.exports = { loginUser, signUpUser, getUser, verifyEmail, forgotPassword, resetPassword }