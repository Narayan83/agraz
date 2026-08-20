import React, { useMemo, useState } from "react";
import {
  Building2,
  CheckCircle2,
  Folder,
  Loader2,
  Mail,
  NotebookPen,
  Phone,
  Store,
  User,
} from "lucide-react";
import { registerBusinessPublic } from "../api/api";
import { MAIN_CATEGORIES, SERVICE_CATEGORIES } from "../lib/serviceCategories";
import "./PublicServiceRegister.css";

const emptyForm = () => ({
  name: "",
  mobile: "",
  email: "",
  main_category: "",
  sub_category: "",
  business_name: "",
  remarks: "",
});

const PublicServiceRegister = () => {
  const [form, setForm] = useState(emptyForm);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [done, setDone] = useState(false);

  const subCategories = useMemo(() => {
    if (!form.main_category) return [];
    return SERVICE_CATEGORIES[form.main_category] || [];
  }, [form.main_category]);

  const setField = (key, value) => {
    setForm((prev) => {
      const next = { ...prev, [key]: value };
      if (key === "main_category") next.sub_category = "";
      return next;
    });
    setErrors((prev) => ({ ...prev, [key]: "" }));
    setSubmitError("");
  };

  const validate = () => {
    const next = {};
    if (!form.name.trim()) next.name = "Required";
    const mobile = form.mobile.trim();
    if (!mobile) next.mobile = "Required";
    else if (!/^\d{10}$/.test(mobile)) next.mobile = "Enter a 10-digit mobile number";
    if (form.email.trim() && !form.email.includes("@")) next.email = "Enter a valid email";
    if (!form.main_category) next.main_category = "Required";
    if (!form.sub_category) next.sub_category = "Required";
    if (!form.business_name.trim()) next.business_name = "Required";
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    setSubmitError("");
    try {
      const payload = {
        mobile: form.mobile.trim(),
        name: form.name.trim(),
        main_category: form.main_category,
        sub_category: form.sub_category,
        business_name: form.business_name.trim(),
      };
      if (form.email.trim()) payload.email = form.email.trim();
      if (form.remarks.trim()) payload.remarks = form.remarks.trim();

      const data = await registerBusinessPublic(payload);
      if (data?.success === false) {
        setSubmitError(data.message || "Failed to register. Try again.");
        return;
      }
      setDone(true);
      setForm(emptyForm());
    } catch (err) {
      setSubmitError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          "Failed to register. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="psr-page">
      <header className="psr-hero">
        <div className="psr-logo">Ag</div>
        <div>
          <h1>Register your Business or Service</h1>
          <p>Fill in the details below. No login needed — same listing as the AgRaz app.</p>
        </div>
      </header>

      {done ? (
        <div className="psr-success">
          <CheckCircle2 size={40} />
          <h2>Service registered successfully</h2>
          <p>
            Your details were saved. The listing will appear in the app after it is approved.
          </p>
          <button type="button" className="psr-submit" onClick={() => setDone(false)}>
            Register another
          </button>
        </div>
      ) : (
        <form className="psr-form" onSubmit={handleSubmit} noValidate>
          {submitError && <div className="psr-alert">{submitError}</div>}

          <section className="psr-card">
            <div className="psr-card-title">
              <Phone size={18} />
              <div>
                <h2>Contact Info</h2>
                <p>How can we reach you?</p>
              </div>
            </div>
            <label className="psr-field">
              <span>Full Name <em>*</em></span>
              <div className="psr-input">
                <User size={18} />
                <input
                  value={form.name}
                  onChange={(e) => setField("name", e.target.value)}
                  placeholder="Full Name"
                  autoComplete="name"
                />
              </div>
              {errors.name && <small>{errors.name}</small>}
            </label>
            <label className="psr-field">
              <span>Mobile Number <em>*</em></span>
              <div className="psr-input">
                <Phone size={18} />
                <input
                  value={form.mobile}
                  onChange={(e) => setField("mobile", e.target.value.replace(/\D/g, "").slice(0, 10))}
                  placeholder="10-digit mobile"
                  inputMode="numeric"
                  autoComplete="tel"
                />
              </div>
              {errors.mobile && <small>{errors.mobile}</small>}
            </label>
            <label className="psr-field">
              <span>Email Address</span>
              <div className="psr-input">
                <Mail size={18} />
                <input
                  type="email"
                  value={form.email}
                  onChange={(e) => setField("email", e.target.value)}
                  placeholder="Optional"
                  autoComplete="email"
                />
              </div>
              {errors.email && <small>{errors.email}</small>}
            </label>
          </section>

          <section className="psr-card">
            <div className="psr-card-title">
              <Folder size={18} />
              <div>
                <h2>Service Category</h2>
                <p>Choose the best match</p>
              </div>
            </div>
            <label className="psr-field">
              <span>Main Category <em>*</em></span>
              <div className="psr-input">
                <Folder size={18} />
                <select
                  value={form.main_category}
                  onChange={(e) => setField("main_category", e.target.value)}
                >
                  <option value="">Select main category</option>
                  {MAIN_CATEGORIES.map((c) => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              </div>
              {errors.main_category && <small>{errors.main_category}</small>}
            </label>
            <label className="psr-field">
              <span>Sub Category <em>*</em></span>
              <div className="psr-input">
                <Store size={18} />
                <select
                  value={form.sub_category}
                  onChange={(e) => setField("sub_category", e.target.value)}
                  disabled={!form.main_category}
                >
                  <option value="">
                    {form.main_category ? "Select sub category" : "Select main category first"}
                  </option>
                  {subCategories.map((c) => (
                    <option key={c} value={c}>{c}</option>
                  ))}
                </select>
              </div>
              {errors.sub_category && <small>{errors.sub_category}</small>}
            </label>
          </section>

          <section className="psr-card">
            <div className="psr-card-title">
              <Building2 size={18} />
              <div>
                <h2>Business Name</h2>
                <p>Name shown to farmers</p>
              </div>
            </div>
            <label className="psr-field">
              <span>Business Name <em>*</em></span>
              <div className="psr-input">
                <Store size={18} />
                <input
                  value={form.business_name}
                  onChange={(e) => setField("business_name", e.target.value)}
                  placeholder="Business Name"
                  autoComplete="organization"
                />
              </div>
              {errors.business_name && <small>{errors.business_name}</small>}
            </label>
          </section>

          <section className="psr-card">
            <div className="psr-card-title">
              <NotebookPen size={18} />
              <div>
                <h2>Remarks</h2>
                <p>Anything else we should know?</p>
              </div>
            </div>
            <label className="psr-field">
              <span>Remarks</span>
              <textarea
                value={form.remarks}
                onChange={(e) => setField("remarks", e.target.value)}
                placeholder="Optional notes"
                rows={3}
              />
            </label>
          </section>

          <button type="submit" className="psr-submit" disabled={submitting}>
            {submitting ? (
              <>
                <Loader2 className="psr-spin" size={20} /> Registering…
              </>
            ) : (
              "Register Service"
            )}
          </button>
        </form>
      )}
    </div>
  );
};

export default PublicServiceRegister;
